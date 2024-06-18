import Decay     "../Decay";

import Map       "mo:map/Map";

import Float     "mo:base/Float";
import Option    "mo:base/Option";
import Debug     "mo:base/Debug";

module {

    type Time = Int;
    type DecayModel = Decay.DecayModel;

    public type IHotInfoBuilder<V> = {
        add_hot: ({ hotness: Float; decay: Float; }) -> ();
        build: () -> V;
    };

    public type HotInfo = {
        amount: Nat;
        timestamp: Int;
        decay: Float;
        hotness: Float;
    };
    
    public class HotMap<K, V>({
        decay_model: DecayModel;
        get_elem: V -> HotInfo;
        update_elem: (V, HotInfo) -> V;
        key_hash: Map.HashUtils<K>;
    }){

        // Creates a new elem with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the elem from the previous elems
        // Update the hotness of the previous elems
        public func add_new({
            map: Map.Map<K, V>;
            key: K;
            builder: IHotInfoBuilder<V>;
            amount: Nat;
            timestamp: Time;
        }) : V {

            if (Map.has(map, key_hash, key)) {
                Debug.trap("Cannot add a elem with a key that is already in the map");
            };

            Option.iterate(Map.peek(map), func((_, previous) : (K, V)) {
                if (get_elem(previous).timestamp >= timestamp) {
                    Debug.trap("Cannot add a elem with a timestamp inferior than the previous elem");
                };
            });

            // The hotness of an elem is the amount of that elem, plus the sum of the previous elem
            // amounts weighted by their growth, plus the sum of the next elem amounts weighted
            // by their decay:
            //
            //  hotness_i = amount_i
            //            + (growth_0  * amount_0   + ... + growth_i-1 * amount_i-1) / growth_i
            //            + (decay_i+1 * amount_i+1 + ... + decay_n    * amount_n  ) / decay_i
            //
            //                 elem 0                elem i                   elem n
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
            // weighting the previous elems and the next elems. The hotness can be simplified to:
            //
            //  hotness_i = amount_i
            //            + (decay_0 / decay_i  ) * amount_0   + ... + (decay_i-1 / decay_i) * amount_i-1
            //            + (decay_i / decay_i+1) * amount_i+1 + ... + (decay_i  / decay_n ) * amount_n

            let decay = decay_model.computeDecay(timestamp);

            var hotness = Float.fromInt(amount);

            // Iterate over the previous elems
            for ((id, prv) in Map.entries(map)) {

                let prev_elem = get_elem(prv);

                // Compute the weight between the two elems
                let weight = prev_elem.decay / decay;

                // Add to the hotness of the new elem
                hotness += Float.fromInt(prev_elem.amount) * weight;
                
                // Update the hotness of the previous elem
                Map.set(map, key_hash, id, update_elem(prv, { 
                    prev_elem with 
                    hotness = prev_elem.hotness + Float.fromInt(amount) * weight
                }));
            };

            // Add the new elem
            builder.add_hot({ hotness; decay; });
            let elem = builder.build();
            Map.set(map, key_hash, key, elem);
            elem;
        };

    };

};
