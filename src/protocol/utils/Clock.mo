import Duration "../duration/Duration";
import Types "../Types";

import Int "mo:base/Int";
import Time "mo:base/Time";
import Result "mo:base/Result";

module {

    type Duration = Duration.Duration;
    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type ClockParameters = Types.ClockParameters;

    public class Clock(params: ClockParameters) {

        public func add_offset(duration: Duration) : Result<(), Text> {
            if (not params.mutable) {
                return #err("Clock offset is immutable");
            };
            params.offset_ns += Int.abs(Duration.toTime(duration));
            #ok;
        };

        public func get_offset() : Duration {
            Duration.fromTime(params.offset_ns);
        };

        public func get_time() : Time {
            Time.now() + params.offset_ns;
        };

    };

};