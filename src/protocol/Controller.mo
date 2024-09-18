import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Int                "mo:base/Int";
import Buffer             "mo:base/Buffer";
import Array              "mo:base/Array";
import Option             "mo:base/Option";

module {

    type Time = Int;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type VoteBallotId = Types.VoteBallotId;
    type ChoiceType = Types.ChoiceType;

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
        reward_facade: PayementFacade.PayementFacade;
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

            let put_args = { vote_type; choice_type; args = { from = { owner = caller; subaccount = from_subaccount; }; time; amount; } };

            await* vote_type_controller.put_ballot(put_args);
        };

        public func try_refund_and_reward({ time: Time; }) : async* [VoteBallotId] {

            let buffer = Buffer.Buffer<VoteBallotId>(0);

            for ((vote_id, vote_type) in Map.entries(vote_register.votes)){
                let ballot_ids = await* vote_type_controller.try_refund_and_reward({ vote_type; time; });
                for (ballot_id in Array.vals(ballot_ids)){
                    buffer.add({vote_id; ballot_id;});
                };
            };

            Buffer.toArray(buffer);
        };

        public func get_votes({origin: Principal;}) : [VoteType] {
            let vote_ids = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<Nat>());
            Set.toArrayMap(vote_ids, func(vote_id: Nat) : ?VoteType {
                Map.get(vote_register.votes, Map.nhash, vote_id);
            });
        };

        public func find_ballot({vote_id: Nat; ballot_id: Nat;}) : ?BallotType {
            
            let vote_type = switch(Map.get(vote_register.votes, Map.nhash, vote_id)){
                case(?v) { v; };
                case(null) { return null; };
            };

            vote_type_controller.find_ballot({ vote_type; ballot_id; });
        };

        public func get_deposit_incidents() : [(Nat, Types.Incident)] {
            deposit_facade.get_incidents();
        };
        
        public func get_reward_incidents() : [(Nat, Types.Incident)] {
            reward_facade.get_incidents();
        };

    };

};