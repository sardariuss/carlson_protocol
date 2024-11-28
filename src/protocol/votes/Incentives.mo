import Types  "../Types";
import Math   "../utils/Math";
import Duration "../duration/Duration";

import Float  "mo:base/Float";
import Int    "mo:base/Int";

module {

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
        steepness: Float;
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
            sigma = length * steepness;
        });
    };

    public func compute_dissent({
        initial_addend: Float;
        steepness: Float;
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
        let c = opposit + initial_addend;

        var dissent = Float.min(b, c) - Float.min(a, c);
        if (Float.equalWithin(steepness, 1.0, 1e-3)) {
            dissent += c * Float.log(Float.max(b, c) / Float.max(a, c));
        } else {
            dissent += (c ** steepness) / (1 - steepness) * 
                       (Float.max(b, c) ** (1 - steepness) - Float.max(a, c) ** (1 - steepness));
        };

        dissent / amount;
    };
}