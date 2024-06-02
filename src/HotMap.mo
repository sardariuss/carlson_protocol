import Decay   "Decay";

import Map     "mo:map/Map";

import Float   "mo:base/Float";
import Int     "mo:base/Int";
import Option  "mo:base/Option";

module {

    type Map<K, V> = Map.Map<K, V>;
    type Time = Int;
    type DecayModel = Decay.DecayModel;

    type GetInputs<V> = V -> { 
        amount: Float; 
        timestamp: Time; 
    };

    type GetOutputs<H> = H -> { 
        amount: Float;
        timestamp: Time;
        decay: Float;
        hotness: Float; 
    };

    type ToHot<V, H> = {
        v: V;
        decay: Float;
        hotness: Float;
    } -> H;


    type UpdateHot<H> = {
        elem: H;
        hotness: Float;
    } -> H;

    public class HotMap<K, V, H>({
        map: Map<K, H>;
        k_hash: Map.HashUtils<K>;
        get_inputs: GetInputs<V>;
        get_outputs: GetOutputs<H>;
        to_hot: ToHot<V, H>;
        update_hotness: UpdateHot<H>;
        decay_model: DecayModel;
    }){

        public func set(k: K, v: V) {

            // The hotness of a lock is the amount of that lock, plus the sum of the previous lock
            // amounts weighted by their growth, plus the sum of the next lock amounts weighted
            // by their decay:
            //
            //  hotness_i = amount_i
            //            + (growth_0  * amount_0   + ... + growth_i-1 * amount_i-1) / growth_i
            //            + (decay_i+1 * amount_i+1 + ... + decay_n    * amount_n  ) / decay_i
            //
            //                 lock 0                lock i                   lock n
            //                       
            //                    |                    |                        |
            //   growth           |                    |                        |          ·
            //     ↑              |                    |                        |        ···
            //       → time       |                    |                        ↓    ·······
            //                    |                    |                     ···············
            //                    ↓                    ↓     ·······························
            //               ·······························································
            //
            //                    |                    |                        |           
            //               ·    |                    |                        |
            //   decay       ···  ↓                    |                        |
            //     ↑         ·······                   |                        |
            //       → time  ···············           ↓                        |
            //               ·······························                    ↓
            //               ·······························································
            //
            // Since we use the same rate for growth and decay, we can use the same weight for 
            // weighting the previous locks and the next locks. The hotness can be simplified to:
            //
            //  hotness_i = amount_i
            //            + (decay_0 / decay_i  ) * amount_0   + ... + (decay_i-1 / decay_i) * amount_i-1
            //            + (decay_i / decay_i+1) * amount_i+1 + ... + (decay_i  / decay_n ) * amount_n

            let { amount; timestamp; } = get_inputs(v);

            // Ensure the timestamp of the previous element is smaller than the given timestamp
            Option.iterate(Map.peek(map), func((_, previous) : (K, H)) {
                assert(get_outputs(previous).timestamp < timestamp);
            });

            let decay = decay_model.computeDecay(timestamp);

            var hotness : Float = 0;

            // Iterate over the previous elements
            for ((prev_k, prv_v) in Map.entries(map)) {

                let previous = get_outputs(prv_v);

                // Compute the weight between the two locks
                let weight = previous.decay / decay;

                // Add to the hotness of the new lock
                hotness += previous.amount * weight;

                // Add to the hotness of the previous lock
                Map.set(map, k_hash, prev_k, update_hotness({ 
                    elem = prv_v;
                    hotness = previous.hotness + amount * weight; 
                }));
            };

            Map.set(map, k_hash, k, to_hot({ v; decay; hotness; }));
        };
        
    };

}