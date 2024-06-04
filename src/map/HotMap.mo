import IMap             "IMap";
import BaseMapComposite "BaseMapComposite";
import Decay            "../Decay";

import Map              "mo:map/Map";

import Option           "mo:base/Option";

module {

    type IMapComposite<K, V, T> = IMap.IMapComposite<K, V, T>;
    type Map<K, V> = Map.Map<K, V>;
    type Time = Int;
    type DecayModel = Decay.DecayModel;

    public type GetInputs<T> = T -> { 
        amount: Float; 
        timestamp: Time; 
    };

    public type GetOutputs<V> = V -> { 
        amount: Float;
        timestamp: Time;
        decay: Float;
        hotness: Float; 
    };

    public type ToHot<T, V> = {
        elem: T;
        decay: Float;
        hotness: Float;
    } -> V;


    public type UpdateHot<V> = {
        elem: V;
        hotness: Float;
    } -> V;

    public class HotMap<K, V, T>({
        decay_model: DecayModel;
        converters: {
            get_inputs: GetInputs<T>;
            get_outputs: GetOutputs<V>;
            to_hot: ToHot<T, V>;
            update_hotness: UpdateHot<V>;
        };
    }){

        func get_new(map: Map<K, V>, hash: Map.HashUtils<K>) : T -> V {
            
            func new(elem: T) : V {

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

                let { amount; timestamp; } = converters.get_inputs(elem);

                // Ensure the timestamp of the previous element is smaller than the given timestamp
                Option.iterate(Map.peek(map), func((_, previous) : (K, V)) {
                    assert(converters.get_outputs(previous).timestamp < timestamp);
                });

                let decay = decay_model.computeDecay(timestamp);

                var hotness : Float = 0;

                // Iterate over the previous elements
                for ((prev_k, prv_v) in Map.entries(map)) {

                    let previous = converters.get_outputs(prv_v);

                    // Compute the weight between the two elems
                    let weight = previous.decay / decay;

                    // Add to the hotness of the new elem
                    hotness += previous.amount * weight;

                    // Add to the hotness of the previous elem
                    Map.set(map, hash, prev_k, converters.update_hotness({ 
                        elem = prv_v;
                        hotness = previous.hotness + amount * weight; 
                    }));
                };

                converters.to_hot({ elem; decay; hotness; });
            };

            new;
        };

        public func get_map_composite({
            map: Map<K, V>;
            hash: Map.HashUtils<K>;
        }) : IMapComposite<K, V, T> {
            BaseMapComposite.BaseMapComposite<K, V, T>(map, hash, get_new(map, hash));
        };

    };

};