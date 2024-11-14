import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import PresenceDispenser  "PresenceDispenser";
import MintController     "payement/MintController";
import MapUtils           "utils/Map";
import Decay              "duration/Decay";
import Incentives         "votes/Incentives";
import VoteUtils          "votes/VoteUtils";

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
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;
    type ExtendedLock = PresenceDispenser.ExtendedLock;

    type WeightParams = {
        ballot: BallotType;
        update_ballot: (BallotType) -> ();
        weight: Float;
    };

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
        deposit_facade: PayementFacade.PayementFacade;
        presence_facade: PayementFacade.PayementFacade;
        resonance_facade: PayementFacade.PayementFacade;
        presence_dispenser: PresenceDispenser.PresenceDispenser;
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

        public func run({ time: Time; }) : async* () {

            let release_attempts = Buffer.Buffer<ReleaseAttempt<BallotType>>(0);

            // TODO: parallelize awaits*
            for ((vote_id, vote_type) in Map.entries(vote_register.votes)){
                await* vote_type_controller.try_release({ 
                    vote_type; 
                    time; 
                    on_release_attempt = func(attempt: ReleaseAttempt<BallotType>) {
                        release_attempts.add(attempt);
                    };
                });
            };

            ignore presence_dispenser.dispense({ 
                locks = Buffer.toArray(Buffer.map<ReleaseAttempt<BallotType>, ExtendedLock>(release_attempts, to_lock)); 
                time_dispense = time
            });

            // TODO: parallelize awaits*
            for ({ elem; release_time; } in release_attempts.vals()){
                if(Option.isSome(release_time)){                    
                    // Mint the presence
                    let _ = await* presence_facade.send_payement({ 
                        to = VoteUtils.get_account(elem); 
                        amount = Int.abs(Float.toInt(VoteUtils.get_presence(elem)));
                    });
                    // Mint the resonance
                    let _ = await* resonance_facade.send_payement({ 
                        to = VoteUtils.get_account(elem); 
                        amount = Int.abs(Float.toInt(Incentives.compute_resonance({
                            amount = VoteUtils.get_amount(elem);
                            dissent = VoteUtils.get_dissent(elem);
                            consent = VoteUtils.get_consent(elem);
                            start = VoteUtils.get_timestamp(elem);
                            end = time;
                        })));
                    });
                };
            };
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
        
        public func get_presence_incidents() : [(Nat, Types.Incident)] {
            presence_facade.get_incidents();
        };

        public func get_resonance_incidents() : [(Nat, Types.Incident)] {
            resonance_facade.get_incidents();
        };

        func to_lock(attempt: ReleaseAttempt<BallotType>) : ExtendedLock {
            {
                attempt with
                amount = switch(attempt.elem){ case(#YES_NO(b)) { b.amount; }; };
                add_presence = func(presence: Float) {
                    attempt.update_elem(VoteUtils.add_presence(attempt.elem, presence));
                };
            };
        };

    };

};