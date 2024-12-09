import Types     "../Types";
import Duration  "Duration";
import Timeline  "../utils/Timeline";

import Float     "mo:base/Float";
import Int       "mo:base/Int";

module {

    type Time = Int;

    public type IDurationCalculator = {
        compute_duration_ns: Float -> Nat;
    };

    type LockElem = {
        timestamp: Time;
        var lock: ?Types.LockInfo;
    };

    // https://www.desmos.com/calculator/9beo92hvwn
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
    }) : IDurationCalculator {

        let nominal_duration_ns = Duration.toTime(nominal_duration);
        let scale_factor = Float.log(2.0) / Float.log(10.0);

        public func compute_duration_ns(hotness: Float) : Nat {
            Int.abs(Float.toInt(Float.fromInt(nominal_duration_ns) * Float.pow(hotness, scale_factor)));
        };

        public func update_lock_duration(elem: LockElem, hotness: Float, time: Time) {
            let duration = compute_duration_ns(hotness);
            let release_date = elem.timestamp + duration;
            switch(elem.lock) {
                case(null) { 
                    elem.lock := ?{
                        duration_ns = Timeline.initialize(time, duration);
                        var release_date = release_date;
                    };
                };
                case(?lock) {
                    if (release_date != lock.release_date) {
                        Timeline.add(lock.duration_ns, time, duration);
                        lock.release_date := release_date;
                    };
                };
            };
        };
    
    };
}