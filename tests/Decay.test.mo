import Decay "../src/Decay";
import Duration "../src/Duration";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Float "mo:base/Float";

import { verify; Testify; } = "utils/Testify";

suite("Decay", func(){

    test("Simple decay", func(){
        let t0 = Time.now();
        let decay_model = Decay.DecayModel({ half_life = #HOURS(1); time_init = t0; });

        let decay_1 = decay_model.compute_decay(t0);
        let decay_2 = decay_model.compute_decay(t0 + Duration.toTime(#HOURS(1)));

        verify<Float>(decay_2/decay_1, 2.0, Testify.float.equalEpsilon9);
    });
    
})