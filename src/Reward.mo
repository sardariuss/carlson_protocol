import Types  "Types";
import Math   "Math";

import Float  "mo:base/Float";
import Iter   "mo:base/Iter";
import Int    "mo:base/Int";

module {

    
    // This abritrary parameter is used to "tighten" the logistic regression used for the reward so that 
    // for every values of x within the range [0, total_amount], y will be within the range [0, 1]
    // (or [0.00669285092428, 0.993307149076] to be precise)
    let K = 0.1;
    
    public func compute_reward({
        total_ayes: Nat; 
        total_nays: Nat;
        lock: Types.TokensLock;
    }) : Nat {
        let { alignement; amount; } = switch(lock.ballot){
            case(#AYE(amount)) { { amount; alignement = Float.fromInt(total_ayes) / Float.fromInt(total_ayes + total_nays); } };
            case(#NAY(amount)) { { amount; alignement = Float.fromInt(total_nays) / Float.fromInt(total_ayes + total_nays); } };
        };
        Int.abs(Float.toInt(Float.fromInt(amount) * alignement * lock.contest_factor));
    };

    public func compute_contest_factor({
        ballot: Types.Ballot;
        vote: Types.Vote;
    }) : Float {
        let { amount; total_same; total_opposit; } = switch(ballot){
            case(#AYE(amount)) { { amount; total_same = vote.total_ayes; total_opposit = vote.total_nays; }; };
            case(#NAY(amount)) { { amount; total_same = vote.total_nays; total_opposit = vote.total_ayes; }; };
        };
        contest_logistic_regression({ amount; total_same; total_opposit; });
    };

    public func contest_logistic_regression({
        amount: Nat;
        total_same: Nat;
        total_opposit: Nat;
    }) : Float {
        let length = Float.fromInt(total_same + total_opposit + amount);
        var accumulation : Float = 0;
        for (i in Iter.range(0, amount - 1)) {
            accumulation += Math.logistic_regression({
                x = length * Float.fromInt(total_opposit) / (Float.fromInt(total_same + total_opposit + i) + 0.5);
                mu = length * 0.5;
                sigma = length * K;
            });
        };
        accumulation;
    };
}