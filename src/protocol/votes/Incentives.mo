import Types  "../Types";
import Math   "../utils/Math";

import Float  "mo:base/Float";

module {

    type YesNoChoice = Types.YesNoChoice;

    // This abritrary parameter is used to "tighten" the logistic regression used for the consent so that 
    // for every values of x within the range [0, total], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let LOGISTIC_REGRESION_K = 0.1;
    
    public func compute_consent({
        choice: Types.YesNoChoice;
        aggregate: Types.YesNoAggregate;
    }) : Float {
        let { same; opposit; } = switch(choice){
            case(#YES) { { same = Float.fromInt(aggregate.total_yes); opposit = Float.fromInt(aggregate.total_no);  }; };
            case(#NO)  { { same = Float.fromInt(aggregate.total_no);  opposit = Float.fromInt(aggregate.total_yes); }; };
        };
        let length = same + opposit;
        Math.logistic_regression({
            x = same;
            mu = length * 0.5;
            sigma = length * LOGISTIC_REGRESION_K;
        });
    };

    let INITIAL_CONTEST_ADDEND = 100.0;

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
        let c = opposit + INITIAL_CONTEST_ADDEND;

        (Float.min(b, c) - Float.min(a, c) + c * Float.log(Float.max(b, c) / Float.max(a, c))) / amount;
    };
}