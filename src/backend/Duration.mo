import Types "Types";

import Float "mo:base/Float";
import Int   "mo:base/Int";

module {
  // For convenience: from base module
  type Time = Int;

  public type Duration = Types.Duration;
  
    public func toTime(duration: Duration) : Time {
        switch(duration) {
            case(#YEARS(years)){ years * 365 * 24 * 60 * 60 * 1_000_000_000; };
            case(#DAYS(days)){          days * 24 * 60 * 60 * 1_000_000_000; };
            case(#HOURS(hours)){            hours * 60 * 60 * 1_000_000_000; };
            case(#MINUTES(minutes)){           minutes * 60 * 1_000_000_000; };
            case(#SECONDS(seconds)){                seconds * 1_000_000_000; };
            case(#NS(ns)){                                               ns; };
        };
    };

    public func fromTime(time: Time) : Duration {
        assert(time > 0);
        let time_nat = Int.abs(time);
        let time_float = Float.fromInt(time);
        if (Float.rem(time_float,  365 * 24 * 60 * 60 * 1_000_000_000) == 0.0){
            return #DAYS(time_nat / (365 * 24 * 60 * 60 * 1_000_000_000));
        };
        if (Float.rem(time_float,        24 * 60 * 60 * 1_000_000_000) == 0.0){
            return #DAYS(time_nat /       (24 * 60 * 60 * 1_000_000_000));
        };
        if(Float.rem(time_float,              60 * 60 * 1_000_000_000) == 0.0){
            return #HOURS(time_nat /           (60 * 60 * 1_000_000_000));
        };
        if(Float.rem(time_float,                   60 * 1_000_000_000) == 0.0){
            return #MINUTES(time_nat /              (60 * 1_000_000_000));
        };
        if(Float.rem(time_float,                        1_000_000_000) == 0.0){
            return #SECONDS(time_nat /                    1_000_000_000);
        };
        return #NS(time_nat);
    };
}