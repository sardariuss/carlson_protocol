import Types "../Types";

import Float "mo:base/Float";
import Int   "mo:base/Int";

module {
    // For convenience: from base module
    type Time = Int;

    public type Duration = Types.Duration;

    public let NS_IN_YEAR = 31_557_600_000_000_000; // 365.25 * 24 * 60 * 60 * 1_000_000_000
    public let NS_IN_DAY = 86_400_000_000_000; // 24 * 60 * 60 * 1_000_000_000
    public let NS_IN_HOUR = 3_600_000_000_000; // 60 * 60 * 1_000_000_000
    public let NS_IN_MINUTE = 60_000_000_000; // 60 * 1_000_000_000
    public let NS_IN_SECOND = 1_000_000_000;
  
    public func toTime(duration: Duration) : Time {
        switch (duration) {
            case (#YEARS(years)) { NS_IN_YEAR * years; };
            case (#DAYS(days)) { NS_IN_DAY * days; };
            case (#HOURS(hours)) { NS_IN_HOUR * hours; };
            case (#MINUTES(minutes)) { NS_IN_MINUTE * minutes; };
            case (#SECONDS(seconds)) { NS_IN_SECOND * seconds; };
            case (#NS(ns)) { ns; };
        };
    };


    public func fromTime(time: Time) : Duration {
        assert(time > 0);
        let time_nat = Int.abs(time);
        let time_float = Float.fromInt(time);
        if (Float.rem(time_float,  Float.fromInt(NS_IN_YEAR)) == 0.0){
            return #DAYS(time_nat / NS_IN_YEAR);
        };
        if (Float.rem(time_float, Float.fromInt(NS_IN_DAY)) == 0.0){
            return #DAYS(time_nat / NS_IN_DAY);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_HOUR)) == 0.0){
            return #HOURS(time_nat / NS_IN_HOUR);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_MINUTE)) == 0.0){
            return #MINUTES(time_nat / NS_IN_MINUTE);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_SECOND)) == 0.0){
            return #SECONDS(time_nat / NS_IN_SECOND);
        };
        return #NS(time_nat);
    };
}