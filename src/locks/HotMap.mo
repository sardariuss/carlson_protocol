import Decay     "../Decay";

import Map       "mo:map/Map";

import IMap      "../map/IMap";

import Float     "mo:base/Float";
import Option    "mo:base/Option";
import Debug     "mo:base/Debug";

module {

    type Time = Int;
    type DecayModel = Decay.DecayModel;

    public type HotInfo = {
        decay: Float;
        hotness: Float;
    };

    type Composite<S> = { slice: S } and HotInfo;

    type CompositeConverters<V, S> = {
        to: V -> Composite<S>;
        from: Composite<S> -> V;
    };
    
    public class HotMap<K, V, S>({
        decay_model: DecayModel;
        get_info: S -> { amount: Nat; timestamp: Time };
        converters: CompositeConverters<V, S>;
    }) {

        // Creates a new elem with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the elem from the previous elems
        // Update the hotness of the previous elems
        public func set_from_slice(
            map: Map.Map<K, V>,
            key_hash: Map.HashUtils<K>,
            key: K,
            slice: S,
        ) : V {

            let { amount; timestamp } = get_info(slice);

            if (Map.has(map, key_hash, key)) {
                Debug.trap("Cannot add a elem with a key that is already in the map");
            };

            Option.iterate(Map.peek(map), func((_, previous) : (K, V)) {
                if (get_info(converters.to(previous).slice).timestamp >= timestamp) {
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

                let previous = converters.to(prv);

                // Compute the weight between the two elems
                let weight = previous.decay / decay;

                // Add to the hotness of the new elem
                hotness += Float.fromInt(get_info(previous.slice).amount) * weight;
                
                // Update the hotness of the previous elem
                Map.set(map, key_hash, id, converters.from({ 
                    previous with hotness = previous.hotness + Float.fromInt(amount) * weight
                }));
            };

            // Add the new elem
            let elem = converters.from({ slice; decay; hotness; });
            Map.set(map, key_hash, key, elem);
            elem;
        };

    };

};
