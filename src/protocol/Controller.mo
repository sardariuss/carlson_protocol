import Types              "Types";
import VoteTypeController "votes/VoteTypeController";

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
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type PutBallotResult = Types.PutBallotResult;
    type VoteBallotId = Types.VoteBallotId;

    public class Controller({
        vote_register: VoteRegister;
        vote_type_controller: VoteTypeController.VoteTypeController;
    }){

        public func new_vote(args: NewVoteArgs) : Nat {

            // Get the next vote_id
            let vote_id = vote_register.index;
            vote_register.index := vote_register.index + 1;

            // Add the vote
            let vote = vote_type_controller.new_vote({
                vote_type_enum = args.type_enum;
                date = args.time;
                origin = args.origin;
            });
            Map.set(vote_register.votes, Map.nhash, vote_id, vote);

            // Add the vote_id to the origin's votes
            Set.add(Option.get(Map.get(vote_register.by_origin, Map.phash, args.origin), Set.new<Nat>()), Map.nhash, vote_id);
            
            vote_id;
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { vote_id; choice_type; } = args;

            switch(Map.get(vote_register.votes, Map.nhash, vote_id)){
                case(?vote_type) { await* vote_type_controller.put_ballot({ vote_type; choice_type; args; }); };
                case(null) {  #err(#VoteNotFound({vote_id}));  };
            };
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

    };

};