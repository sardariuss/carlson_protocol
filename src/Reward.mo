import Types  "Types";
import Math   "Math";

import Float  "mo:base/Float";
import Debug  "mo:base/Debug";
import Iter   "mo:base/Iter";

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
        let { total_same; total_opposit; } = switch(choice){
            case(#AYE(_)) { { total_same = total_ayes; total_opposit = total_nays; }; };
            case(#NAY(_)) { { total_same = total_nays; total_opposit = total_ayes; }; };
        };
        let length = Float.fromInt(total_same + total_opposit);
        Math.logistic_regression({
            x = Float.fromInt(total_same);
            mu = length * 0.5;
            sigma = length * K;
        });
    };

    public func compute_contest_factor({
        total_ayes: Nat; 
        total_nays: Nat;
        choice: Types.Choice;
    }) : Float {
        let { amount; total_same; total_opposit; } = switch(choice){
            case(#AYE(amount)) { { amount; total_same = total_ayes; total_opposit = total_nays; }; };
            case(#NAY(amount)) { { amount; total_same = total_nays; total_opposit = total_ayes; }; };
        };
        linear_contest({ amount; total_same; total_opposit; });
    };

    public func linear_contest({
        amount: Nat;
        total_same: Nat;
        total_opposit: Nat;
    }) : Float {

        if(amount == 0){
            Debug.trap("Amount must be greater than 0");
        };
        
        // If there is no vote yet, the contest factor is 0.5
        if (total_same + total_opposit == 0) {
            return 0.5 * Float.fromInt(amount);
        };

        // Otherwise, accumulate following a slope based on the ratio: opposit / total
        var accumulation : Float = 0;
        for (i in Iter.range(0, amount - 1)) {
            accumulation += Float.fromInt(total_opposit) / (Float.fromInt(total_same + total_opposit + i) + 0.5);
        };

        // Divide the accumulation by the total amount to get the average per coin
        accumulation / Float.fromInt(amount);

    };
}