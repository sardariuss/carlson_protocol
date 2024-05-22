import Types "../Types";
import PayementFacade "../PayementFacade";

import Result         "mo:base/Result";
import VoteController "VoteController";

module {

    type VoteType = Types.VoteType;
    type ChoiceType = Types.ChoiceType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoChoice = Types.YesNoChoice;
    type Time = Int;

    public type VoteId = Nat;

    type AddDepositError = PayementFacade.AddDepositError;
    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    type PutBallotArgs = VoteController.PutBallotArgs;

    public class VoteTypeController({
        yes_no_controller: VoteController.VoteController<YesNoAggregate, YesNoChoice>;
    }){

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs;}) : async* Result<Nat, AddDepositError> {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { await* yes_no_controller.put_ballot({ vote; args; choice; }); };
            };
        };

        public func try_refund_and_reward({
            vote: VoteType;
            time: Time
        }) : async* [Nat] {
            switch(vote){
                case(#YES_NO(vote)) { await* yes_no_controller.try_refund_and_reward({ vote; time; }); };
            };
        };

    };
};