import Types          "Types";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade "PayementFacade";

import Map            "mo:map/Map";

import Int            "mo:base/Int";
import Result         "mo:base/Result";
import Buffer         "mo:base/Buffer";
import Array          "mo:base/Array";

module {

    type VoteId = Nat;
    type ChoiceType = Types.ChoiceType;
    type VoteType = Types.VoteType;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type VoteTypeEnum = Types.VoteTypeEnum;
    type Time = Int;
    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type BallotType = Types.BallotType;

    type SendPayementError = PayementFacade.SendPayementError;
    
    type VoteNotFoundError = { #VoteNotFound: { vote_id: VoteId }; };
    
    public type PutBallotArgs = { vote_id: VoteId; choice_type: ChoiceType; } and VoteTypeController.PutBallotArgs;
    public type PutBallotResult = Result<Nat, PayementFacade.AddDepositError or VoteNotFoundError>;

    public type VoteBallotId = {
        vote_id: VoteId;
        ballot_id: Nat;
    };

    public type NewVoteArgs = {
        caller: Principal;
        from: Account;
        time: Time;
        type_enum: VoteTypeEnum;
    };

    public type NewVoteResult = Result<VoteId, SendPayementError>;

    type VoteRegister = Types.VoteRegister;

    public class Controller({
        vote_register: VoteRegister;
        payement_facade: PayementFacade.PayementFacade;
        vote_type_controller: VoteTypeController.VoteTypeController;
        new_vote_price: Nat;
    }){

        public func new_vote(args: NewVoteArgs) : async* NewVoteResult {

            let payement = await* payement_facade.send_payement({
                caller = args.caller;
                from = args.from;
                amount = new_vote_price;
                time = args.time;
            });

            let tx_id = switch(payement){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            let vote = vote_type_controller.new_vote({
                vote_type_enum = args.type_enum;
                date = args.time;
                author = args.caller;
                tx_id;
            });

            let vote_id = vote_register.index;
            vote_register.index := vote_register.index + 1;
            Map.set(vote_register.votes, Map.nhash, vote_id, vote);
            #ok(vote_id);
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

        public func find_ballot({vote_id: VoteId; ballot_id: Nat;}) : ?BallotType {
            let vote_type = switch(Map.get(vote_register.votes, Map.nhash, vote_id)){
                case(?v) { v; };
                case(null) { return null; };
            };

            vote_type_controller.find_ballot({ vote_type; ballot_id; });
        };

    };

};