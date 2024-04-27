import Types  "Types";
import Math   "Math";

import Float  "mo:base/Float";
import Debug  "mo:base/Debug";

module {

    // This abritrary parameter is used to "tighten" the logistic regression used for the score so that 
    // for every values of x within the range [0, total_amount], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let K = 0.1;
    
    public func compute_score({
        total_ayes: Nat;
        total_nays: Nat;
        choice: Types.Choice;
    }) : Float {
        let { same_amount; opposit_amount; } = switch(choice){
            case(#AYE(_)) { { same_amount = total_ayes; opposit_amount = total_nays; }; };
            case(#NAY(_)) { { same_amount = total_nays; opposit_amount = total_ayes; }; };
        };
        let length = Float.fromInt(same_amount + opposit_amount);
        Math.logistic_regression({
            x = Float.fromInt(same_amount);
            mu = length * 0.5;
            sigma = length * K;
        });
    };

    public func compute_contest_factor({
        choice: Types.Choice;
        total_ayes: Nat; 
        total_nays: Nat;
    }) : Float {

        let { ballot_amount; same_amount; opposit_amount; } = switch(choice){
            case(#AYE(ballot_amount)) { { ballot_amount; same_amount = total_ayes; opposit_amount = total_nays; }; };
            case(#NAY(ballot_amount)) { { ballot_amount; same_amount = total_nays; opposit_amount = total_ayes; }; };
        };

        if(ballot_amount == 0){
            Debug.trap("Ballot amount must be greater than 0");
        };

        let total_amount = same_amount + opposit_amount;
        
        // If there is no vote yet, the contest factor is 0.5
        // @todo: need to find a better way to handle this case
        if (total_amount == 0) {
            return 0.5 * Float.fromInt(ballot_amount);
        };

        // Otherwise, accumulate following a slope based on the ratio: opposit / total
        // and divide by the total amount to get the average contest per coin

        let total_f = Float.fromInt(total_amount);
        let opposit_f = Float.fromInt(opposit_amount);
        let ballot_f = Float.fromInt(ballot_amount);

        opposit_f * (Float.log(total_f + ballot_f) - Float.log(total_f)) / ballot_f;
    };
}