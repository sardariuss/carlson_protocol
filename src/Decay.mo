import Types    "Types";
import Duration "Duration";

import Float    "mo:base/Float";
import Debug    "mo:base/Debug";

module {
    type Time = Int;

    type Duration = Types.Duration;
    type DecayParameters = Types.DecayParameters;

    // @todo: find out how small can the half-life be before the decay becomes too small or too big to be represented by a float64!

    public func computeDecay(params: DecayParameters, date: Time) : Float {
        Float.exp(params.lambda * Float.fromInt(date) - params.shift);
    };

    public func getDecayParameters({half_life: Duration; time_init: Time}) : DecayParameters {
        let lambda = Float.log(2.0) / Float.fromInt(Duration.toTime(half_life));
        let shift = Float.fromInt(time_init) * lambda;
        { lambda; shift; };
    };

};