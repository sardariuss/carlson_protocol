import Types  "Types";
import Math   "Math";

import Float  "mo:base/Float";
import Debug  "mo:base/Debug";

module {

    // This abritrary parameter is used to "tighten" the logistic regression used for the score so that 
    // for every values of x within the range [0, total], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let K = 0.1;
    
    public func compute_score({
        choice: Types.Choice;
        total_yes: Float;
        total_no: Float;
    }) : Float {
        let { same; opposit; } = switch(choice){
            case(#YES(_)) { { same = total_yes; opposit = total_no; }; };
            case(#NO(_)) { { same = total_no; opposit = total_yes; }; };
        };
        let length = same + opposit;
        Math.logistic_regression({
            x = same;
            mu = length * 0.5;
            sigma = length * K;
        });
    };

    public func compute_contest({
        choice: Types.Choice;
        total_yes: Float; 
        total_no: Float;
    }) : Float {

        let { ballot; same; opposit; } = switch(choice){
            case(#YES(ballot)) { { ballot = Float.fromInt(ballot); same = total_yes; opposit = total_no; }; };
            case(#NO(ballot)) { { ballot = Float.fromInt(ballot); same = total_no; opposit = total_yes; }; };
        };

        if(ballot == 0){
            Debug.trap("Ballot amount must be greater than 0");
        };

        let total = same + opposit;
        
        // If there is no vote yet, the contest factor is 0.5
        // @todo: need to find a better way to handle this case
        if (total == 0.0) {
            return 0.5 * ballot;
        };

        // Otherwise, accumulate following a slope based on the ratio: opposit / total
        // and divide by the ballot amount to get the average contest value per coin

        opposit * (Float.log(total + ballot) - Float.log(total)) / ballot;
    };
}