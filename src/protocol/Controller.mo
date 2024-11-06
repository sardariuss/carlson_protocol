import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import MintController     "payement/MintController";
import MapUtils           "utils/Map";
import Decay              "duration/Decay";
import Incentives         "votes/Incentives";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Int                "mo:base/Int";
import Buffer             "mo:base/Buffer";
import Array              "mo:base/Array";
import Option             "mo:base/Option";
import Result             "mo:base/Result";
import Float              "mo:base/Float";

module {

    type Time = Int;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type VoteBallotId = Types.VoteBallotId;
    type ChoiceType = Types.ChoiceType;
    type QueriedBallot = Types.QueriedBallot;
    type Account = Types.Account;
    type VoteId = Types.VoteId;
    type BallotId = Types.BallotId;

    public type NewVoteArgs = {
        origin: Principal;
        time: Time;
        type_enum: Types.VoteTypeEnum;
    };

    public type PutBallotArgs = {
        vote_id: Nat;
        choice_type: ChoiceType;
        caller: Principal;
        from_subaccount: ?Blob;
        time: Time;
        amount: Nat;
    };

    public class Controller({
        vote_register: VoteRegister;
        vote_type_controller: VoteTypeController.VoteTypeController;
        mint_controller: MintController.MintController;
        deposit_facade: PayementFacade.PayementFacade;
        reward_facade: PayementFacade.PayementFacade;
        decay_model: Decay.DecayModel;
    }){

        public func new_vote(args: NewVoteArgs) : VoteType {

            let { type_enum; time; origin; } = args;

            // Get the next vote_id
            let vote_id = vote_register.index;
            vote_register.index := vote_register.index + 1;

            // Add the vote
            let vote = vote_type_controller.new_vote({
                vote_id;
                vote_type_enum = type_enum;
                date = time;
                origin;
            });
            Map.set(vote_register.votes, Map.nhash, vote_id, vote);

            // Update the by_origin map
            let by_origin = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<Nat>());
            Set.add(by_origin, Set.nhash, vote_id);
            Map.set(vote_register.by_origin, Map.phash, origin, by_origin);

            vote;
        };

        public func preview_ballot(args: PutBallotArgs) : PreviewBallotResult {

            let { vote_id; choice_type; caller; from_subaccount; time; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.nhash, args.vote_id)){
                case(?v) { v };
                case(null) { return #err(#VoteNotFound({vote_id}));  };
            };

            let put_args = { vote_type; choice_type; args = { from = { owner = caller; subaccount = from_subaccount; }; time; amount; } };

            #ok(vote_type_controller.preview_ballot(put_args));
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { vote_id; choice_type; caller; from_subaccount; time; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.nhash, args.vote_id)){
                case(?v) { v };
                case(null) { return #err(#VoteNotFound({vote_id}));  };
            };

            let from = { owner = caller; subaccount = from_subaccount; };

            let put_args = { vote_type; choice_type; args = { from; time; amount; } };

            let result = await* vote_type_controller.put_ballot(put_args);

            Result.iterate(result, func(ballot_id: Nat) {
                MapUtils.putInnerSet(vote_register.user_ballots, MapUtils.acchash, from, MapUtils.nnhash, (vote_id, ballot_id));
            });

            result;
        };

        public func get_ballots(account: Account) : [QueriedBallot] {
            switch(Map.get(vote_register.user_ballots, MapUtils.acchash, account)){
                case(?ballots) { 
                    Set.toArrayMap(ballots, func((vote_id, ballot_id): (Nat, Nat)) : ?QueriedBallot =
                        Option.map(find_ballot({vote_id; ballot_id;}), func(ballot: BallotType) : QueriedBallot = 
                            { vote_id; ballot_id; ballot; }
                        )
                    );
                };
                case(null) { [] };
            };
        };

        public func run({ time: Time; }) : async* Nat {

            var total_weights = 0.0;
            
            type WeightParams = {
                account: Account;
                weight: Float;
                add_reward: (Nat) -> ();
            };
            let buffer = Buffer.Buffer<WeightParams>(0);

            let compute_weights = func({vote_type: VoteType; ballot_type: BallotType; update_ballot: (BallotType) -> (); released: ?Time; }) : () {

                let param = switch(vote_type, ballot_type){
                    case(#YES_NO(vote), #YES_NO(ballot)) { 
                        let weight = MintController.compute_weighted_amount({
                            time;
                            released;
                            ballot;
                            aggregate_history = vote.aggregate_history;
                            compute_consent = Incentives.compute_consent;
                        });
                        { 
                            account = ballot.from;
                            weight; 
                            add_reward = func(amount: Nat) { update_ballot(#YES_NO({ ballot with accumulated_reward = ballot.accumulated_reward + amount })); }; 
                        };
                    };
                };

                buffer.add(param);
                total_weights += param.weight;
            };

            for ((vote_id, vote_type) in Map.entries(vote_register.votes)){
                await* vote_type_controller.try_release({ vote_type; time; on_release_attempt = compute_weights; });
            };

            let minting_owed = Map.new<Account, Nat>();
            
            for ({ weight; add_reward; account; } in buffer.vals()){
                
                // Compute the reward
                let reward = MintController.compute_reward({ total_weights; weight = weight; });

                // Add it to the ballot cumulated reward
                add_reward(reward);
                
                // Add it to the minting owed to the account
                ignore Map.update<Account, Nat>(minting_owed, MapUtils.acchash, account, func(k: Account, v: ?Nat) : ?Nat {
                    ?(Option.get(v, 0) + reward);
                });
            };
            
            // Mint the rewards
            var total_amount = 0;
            for ((to, amount) in Map.entries(minting_owed)){
                total_amount += amount;
                // TODO: parallelize
                ignore (await* reward_facade.send_payement({ to; amount; }));
            };

            total_amount;
        };

        public func get_votes({origin: Principal;}) : [VoteType] {
            let vote_ids = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<Nat>());
            Set.toArrayMap(vote_ids, func(vote_id: Nat) : ?VoteType {
                Map.get(vote_register.votes, Map.nhash, vote_id);
            });
        };

        public func find_vote(vote_id: Nat) : ?VoteType {
            Map.get(vote_register.votes, Map.nhash, vote_id);
        };

        public func find_ballot({vote_id: Nat; ballot_id: Nat;}) : ?BallotType {
            
            let vote_type = switch(Map.get(vote_register.votes, Map.nhash, vote_id)){
                case(?v) { v; };
                case(null) { return null; };
            };

            vote_type_controller.find_ballot({ vote_type; ballot_id; });
        };

        public func compute_decay(time: Time) : Float {
            decay_model.compute_decay(time);
        };

        public func get_deposit_incidents() : [(Nat, Types.Incident)] {
            deposit_facade.get_incidents();
        };
        
        public func get_reward_incidents() : [(Nat, Types.Incident)] {
            reward_facade.get_incidents();
        };

    };

};