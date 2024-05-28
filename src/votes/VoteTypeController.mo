import Types "../Types";
import PayementFacade "../PayementFacade";

import Result         "mo:base/Result";
import VoteController "VoteController";
import Option        "mo:base/Option";

module {

    type VoteType = Types.VoteType;
    type ChoiceType = Types.ChoiceType;
    type VoteTypeEnum = Types.VoteTypeEnum;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoChoice = Types.YesNoChoice;
    type YesNoBallot = Ballot<Types.YesNoChoice>;
    type Time = Int;

    public type VoteId = Nat;

    type PayServiceError = PayementFacade.PayServiceError;
    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type BallotType = Types.BallotType;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    public type PutBallotArgs = VoteController.PutBallotArgs;

    public class VoteTypeController({
        yes_no_controller: VoteController.VoteController<YesNoAggregate, YesNoChoice>;
    }){

        public func new_vote({ vote_type_enum: VoteTypeEnum; date: Time; author: Principal; tx_id: Nat; }) : VoteType {
            switch(vote_type_enum){
                case(#YES_NO) { #YES_NO(yes_no_controller.new_vote({date; author; tx_id;})); }
            };
        };

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : async* Result<Nat, PayServiceError> {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { await* yes_no_controller.put_ballot({ vote; args; choice; }); };
            };
        };

        public func try_refund_and_reward({ vote_type: VoteType; time: Time; }) : async* [Nat] {
            switch(vote_type){
                case(#YES_NO(vote)) { await* yes_no_controller.try_refund_and_reward({ vote; time; }); };
            };
        };

        public func find_ballot({ vote_type: VoteType; ballot_id: Nat; }) : ?Types.BallotType {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    Option.map(yes_no_controller.find_ballot({ vote; ballot_id; }), func(b: YesNoBallot) : Types.BallotType { #YES_NO(b); }); 
                };
            };
        };

    };

};