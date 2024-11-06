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
    type ReleaseAttempt<B> = Types.ReleaseAttempt<B>;
    type Time = Int;
    type YesNoVote = Types.Vote<YesNoAggregate, YesNoChoice>;

    public type VoteId = Nat;

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type BallotType = Types.BallotType;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    public type PutBallotArgs = VoteController.PutBallotArgs;

    public class VoteTypeController({
        yes_no_controller: VoteController.VoteController<YesNoAggregate, YesNoChoice>;
    }){

        public func new_vote({ vote_id: Nat; vote_type_enum: VoteTypeEnum; date: Time; origin: Principal; }) : VoteType {
            switch(vote_type_enum){
                case(#YES_NO) { #YES_NO(yes_no_controller.new_vote({vote_id; date; origin;})); }
            };
        };

        public func preview_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : BallotType {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { #YES_NO(yes_no_controller.preview_ballot({ vote; args; choice; })); };
            };
        };

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : async* Result<Nat, PutBallotError> {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { await* yes_no_controller.put_ballot({ vote; args; choice; }); };
            };
        };

        public func try_release({
            vote_type: VoteType;
            on_release_attempt: ({vote_type: VoteType; ballot_type: BallotType; update_ballot: (BallotType) -> (); released: ?Time;}) -> ();
            time: Time;
        }) : async* () {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    await* yes_no_controller.try_release({ 
                        vote; 
                        time; 
                        on_release_attempt = func({vote: YesNoVote; ballot: YesNoBallot; update_ballot: (YesNoBallot) -> (); released: ?Time; }) {
                            on_release_attempt({ 
                                vote_type = #YES_NO(vote);
                                ballot_type = #YES_NO(ballot); 
                                update_ballot = func(b: BallotType) { 
                                    switch(b){
                                        case(#YES_NO(b)) { update_ballot(b); };
                                    };
                                };
                                released;
                            });
                        };
                    }); 
                };
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