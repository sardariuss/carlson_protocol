import Types  "../Types";
import Math   "../utils/Math";
import Duration "../duration/Duration";

import Float  "mo:base/Float";
import Int    "mo:base/Int";

module {

    // This abritrary parameter is used to "tighten" the logistic regression used for the consent so that 
    // for every values of x within the range [0, total], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let LOGISTIC_REGRESION_K = 0.1;
    let INITIAL_DISSENT_ADDEND = 100.0;
    // https://www.desmos.com/calculator/4ecv2x4p2d
    let DISSENT_STEEPNESS = 0.55; // TODO: implement this power function

    type Time = Int;
    type YesNoChoice = Types.YesNoChoice;
    type BallotType = Types.BallotType;
    type YesNoAggregate = Types.YesNoAggregate;
    type AggregateHistoryType = Types.AggregateHistoryType;
    type Segment = { start: Time; end: Time; aggregate: YesNoAggregate; };

    public func compute_resonance({
        amount: Nat;
        dissent: Float;
        consent: Float;
        start: Time;
        end: Time;
    }) : Float {
        let age = Float.fromInt(end - start) / Float.fromInt(Duration.NS_IN_YEAR);
        Float.fromInt(amount) * age * dissent * consent;
    };
    
    public func compute_consent({
        choice: YesNoChoice;
        total_yes: Float;
        total_no: Float;
    }) : Float {
        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no;  }; };
            case(#NO)  { { same = total_no;  opposit = total_yes; }; };
        };
        let length = same + opposit;
        Math.logistic_regression({
            x = same;
            mu = length * 0.5;
            sigma = length * LOGISTIC_REGRESION_K;
        });
    };

    public func compute_dissent({
        choice: YesNoChoice;
        amount: Float;
        total_yes: Float; 
        total_no: Float;
    }) : Float {

        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no; }; };
            case(#NO) { { same = total_no; opposit = total_yes; }; };
        };

        let a = opposit + same;
        let b = a + amount;
        let c = opposit + INITIAL_DISSENT_ADDEND;

        (Float.min(b, c) - Float.min(a, c) + c * Float.log(Float.max(b, c) / Float.max(a, c))) / amount;
    };
}