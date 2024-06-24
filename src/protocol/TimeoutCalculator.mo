import Types     "Types";
import Duration  "Duration";

import Float     "mo:base/Float";
import Int       "mo:base/Int";

module {

    type Time = Int;

    public type ITimeoutCalculator = {
        timeout_date: { timestamp: Time; hotness: Float; } -> Time;
    };

    // The power scaler function is responsible for deducting the timeout date of the given elements
    // from their hotness. It especially aims at preventing absurd durations (e.g. 10 seconds or 100 years).
    // It is defined as a power function of the hotness so that the duration is doubled for each 
    // order of magnitude of hotness:
    //      duration = a * hotness ^ b where 
    // where:
    //      a is the duration for a hotness of 1
    //      b = ln(2) / ln(10)
    //
    //                                                   ································
    //  duration                         ················
    //      ↑                    ········
    //        → hotness      ····
    //                     ··
    //                    ·
    // 
    public class PowerScaler({
        nominal_duration: Types.Duration;
    }) : ITimeoutCalculator {

        let nominal_duration_ns = Duration.toTime(nominal_duration);
        let scale_factor = Float.log(2.0) / Float.log(10.0);

        public func timeout_date({ timestamp: Time; hotness: Float; }) : Time {
            let duration = Int.abs(Float.toInt(Float.fromInt(nominal_duration_ns) * Float.pow(hotness, scale_factor)));
            timestamp + duration;
        };
    
    };
}