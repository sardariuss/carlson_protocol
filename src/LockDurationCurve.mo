import Types     "Types";
import Duration  "Duration";

import Float     "mo:base/Float";
import Int       "mo:base/Int";

module {

    // The lock duration curve is responsible for deducting the time left of each lock from their
    // hotness. It especially aim at preventing absurd locking times (e.g. 10 seconds or 100 years).
    // It is defined as a power function of the hotness so that the duration is doubled for each 
    // order of magnitude of hotness:
    //      duration = a * hotness ^ b where 
    // where:
    //      a is the duration for a hotness of 1
    //      b = ln(2) / ln(10)
    //
    //                                                   ································
    //  lock_time                        ················
    //      ↑                    ········
    //        → hotness      ····
    //                     ··
    //                    ·
    // 
    public class LockDurationCurve({
        nominal_lock_duration: Types.Duration;
    }){

        let nominal_lock_duration_ns = Duration.toTime(nominal_lock_duration);
        let scale_factor = Float.log(2.0) / Float.log(10.0);

        public func get_lock_duration_ns(hotness: Float) : Nat {
            Int.abs(Float.toInt(Float.fromInt(nominal_lock_duration_ns) * Float.pow(hotness, scale_factor)));
        };
    
    };
}