import Types    "../Types";
import Duration "Duration";

import Float    "mo:base/Float";

module {

    type Time = Int;
    type Duration = Types.Duration;
    type Decayed = Types.Decayed;

    public func add(a: Decayed, b: Decayed) : Decayed {
        switch(a) {
            case (#DECAYED(a_value)) {
                switch(b) {
                    case (#DECAYED(b_value)) {
                        #DECAYED(a_value + b_value);
                    };
                };
            };
        };
    };

    public class DecayModel({half_life: Duration; time_init: Time}){

        // @todo: find out how small can the half-life be before the decay becomes too small or too big to be represented by a float64!
        let _lambda = Float.log(2.0) / Float.fromInt(Duration.toTime(half_life));
        let _shift = Float.fromInt(time_init) * _lambda;

        public func create_decayed(value: Float, time: Time) : Decayed {
            #DECAYED(value * compute_decay(time));
        };

        public func unwrap_decayed(decayed: Decayed, now: Time) : Float {
            switch(decayed) {
                case (#DECAYED(value)) {
                    value / compute_decay(now);
                };
            };
        };

        public func compute_decay(time: Time) : Float {
            Float.exp(_lambda * Float.fromInt(time) - _shift);
        };
        
    };
    
};