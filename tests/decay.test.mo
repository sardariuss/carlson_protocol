import Decay "../src/backend/Decay";
import Duration "../src/backend/Duration";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Float "mo:base/Float";

suite("Decay", func(){

    test("Test decay", func(){
        let t0 = Time.now();
        let params = Decay.getDecayParameters({ half_life = #HOURS(1); time_init = t0; });

        let decay_1 = Decay.computeDecay(params, t0);
        let decay_2 = Decay.computeDecay(params, t0 + Duration.toTime(#HOURS(1)));

        Debug.print("decay ratio: " # debug_show(decay_2 / decay_1));
        assert(Float.equalWithin(decay_2 / decay_1, 2.0, 1e-9));
    });
    
})