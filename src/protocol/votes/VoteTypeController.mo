import VoteController "VoteController";
import Types          "../Types";

import Iter           "mo:base/Iter";

module {

    type VoteType       = Types.VoteType;
    type ChoiceType     = Types.ChoiceType;
    type VoteTypeEnum   = Types.VoteTypeEnum;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoChoice    = Types.YesNoChoice;
    type Time           = Int;
    type UUID           = Types.UUID;
    type BallotType     = Types.BallotType;
    
    type Iter<T>        = Iter.Iter<T>;

    // TODO: put in Types.mo
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
                case(#YES_NO(vote), #YES_NO(choice)) { #YES_NO(yes_no_controller.preview_ballot(vote, choice, args)); };
            };
        };

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : BallotType {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { #YES_NO(yes_no_controller.put_ballot(vote, choice, args)); };
            };
        };

        public func vote_ballots(vote_type: VoteType) : Iter<BallotType> {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    let it = yes_no_controller.vote_ballots(vote);
                    func next() : ?(BallotType) {
                        label get_next while(true) {
                            switch(it.next()){
                                case(null) { break get_next; };
                                case(?ballot){
                                    return ?#YES_NO(ballot);
                                };
                            };
                        };
                        null;
                    };
                    return { next };
                };
            };
        };

    };

};