import VoteController "VoteController";
import Types          "../Types";

import Result         "mo:base/Result";
import Option         "mo:base/Option";

module {

    type VoteType = Types.VoteType;
    type ChoiceType = Types.ChoiceType;
    type VoteTypeEnum = Types.VoteTypeEnum;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoChoice = Types.YesNoChoice;
    type PutBallotError = Types.PutBallotError;
    type YesNoBallot = Ballot<Types.YesNoChoice>;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;
    type Time = Int;
    type YesNoVote = Types.Vote<YesNoAggregate, YesNoChoice>;
    type UUID = Types.UUID;

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type BallotType = Types.BallotType;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    public type PutBallotArgs = VoteController.PutBallotArgs;

    public class VoteTypeController({
        yes_no_controller: VoteController.VoteController<YesNoAggregate, YesNoChoice>;
    }){

        public func new_vote({ vote_id: UUID; vote_type_enum: VoteTypeEnum; date: Time; origin: Principal; }) : VoteType {
            switch(vote_type_enum){
                case(#YES_NO) { #YES_NO(yes_no_controller.new_vote({vote_id; date; origin;})); }
            };
        };

        public func preview_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : BallotType {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { #YES_NO(yes_no_controller.preview_ballot({ vote; args; choice; })); };
            };
        };

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : async* Result<UUID, PutBallotError> {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { await* yes_no_controller.put_ballot({ vote; args; choice; }); };
            };
        };

        public func find_ballot({ vote_type: VoteType; ballot_id: UUID; }) : ?Types.BallotType {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    Option.map(yes_no_controller.find_ballot({ vote; ballot_id; }), func(b: YesNoBallot) : Types.BallotType { #YES_NO(b); }); 
                };
            };
        };

    };

};