import Types  "../Types";
import Math   "../utils/Math";

import Float  "mo:base/Float";
import Debug  "mo:base/Debug";

module {

    type YesNoChoice = Types.YesNoChoice;

    // This abritrary parameter is used to "tighten" the logistic regression used for the score so that 
    // for every values of x within the range [0, total], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let K = 0.1;
    
    public func compute_score({
        choice: Types.YesNoChoice;
        total_yes: Float;
        total_no: Float;
    }) : Float {
        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no; }; };
            case(#NO) { { same = total_no; opposit = total_yes; }; };
        };
        let length = same + opposit;
        Math.logistic_regression({
            x = same;
            mu = length * 0.5;
            sigma = length * K;
        });
    };

    public func compute_contest({
        choice: YesNoChoice;
        amount: Float;
        total_yes: Float; 
        total_no: Float;
    }) : Float {

        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no; }; };
            case(#NO) { { same = total_no; opposit = total_yes; }; };
        };

        if(amount == 0){
            Debug.trap("Ballot amount must be greater than 0");
        };

        let total = same + opposit;
        
        // If there is no vote yet, the contest factor is 0.5
        // @todo: use the formula with the constant factor instead
        if (total == 0.0) {
            return 0.5 * amount;
        };

        // Otherwise, accumulate following a slope based on the ratio: opposit / total
        // and divide by the ballot amount to get the average contest value per coin

        opposit * (Float.log(total + amount) - Float.log(total)) / amount;
    };
}