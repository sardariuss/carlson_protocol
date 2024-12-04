import Interfaces "../Interfaces";

import Map        "mo:map/Map";

import Float      "mo:base/Float";
import Result     "mo:base/Result";

module {

    type Time = Int;
    type IDecayModel = Interfaces.IDecayModel;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type IHotElemBuilder<V> = {
        add_hot: (HotOutput, Time) -> ();
        build: () -> V;
    };

    public type HotInput = {
        amount: Nat;
        timestamp: Time;
    };

    public type HotOutput = {
        decay: Float;
        hotness: Float;
    };

    public type HotElem = HotInput and HotOutput;

    public type UpdateHotness<V> = {
        v: V;
        hotness: Float;
        time: Time;
    } -> V;
    
    public class HotMap<K, V>({
        decay_model: IDecayModel;
        get_elem: V -> HotElem;
        update_hotness: UpdateHotness<V>;
        key_hash: Map.HashUtils<K>;
    }){

        // Creates a new elem with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the elem from the previous elems
        // Update the hotness of the previous elems
        public func add_new({
            map: Map.Map<K, V>;
            key: K;
            builder: IHotElemBuilder<V>;
            args: HotInput;
        }) : Result<V, Text> {

            if (Map.has(map, key_hash, key)){
                return #err("Cannot add a elem with a key that is already in the map");
            };

            let { amount; timestamp; } = args;

            switch(Map.peek(map)){
                case(null) {};
                case(?(_, previous)){
                    if (get_elem(previous).timestamp > timestamp) {
                        return #err("Cannot add an elem with a timestamp inferior than the previous elem");
                    };
                };
            };

            let value = set_hot({ map; builder; args; });

            // Iterate over the previous elems
            for ((key, v) in Map.entries(map)) {

                let prev_elem = get_elem(v);

                // Compute the weight between the two elems
                let weight = prev_elem.decay / get_elem(value).decay;

                // Add to the hotness of the new elem
                let hotness = prev_elem.hotness + Float.fromInt(amount) * weight;
                
                // Update the hotness of the previous elem
                let new_value = update_hotness({ v; hotness; time = timestamp; });
                Map.set(map, key_hash, key, new_value);
            };

            // Add the new elem
            Map.set(map, key_hash, key, value);
            #ok(value);
        };

        // Creates a new elem with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the elem from the previous elems
        // Update the hotness of the previous elems
        public func set_hot({
            map: Map.Map<K, V>;
            builder: IHotElemBuilder<V>;
            args: HotInput;
        }) : V {

            let { amount; timestamp; } = args;

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

            let decay = decay_model.compute_decay(timestamp);

            var hotness = Float.fromInt(amount);

            // Iterate over the previous elems
            for ((id, prv) in Map.entries(map)) {

                let old_value = get_elem(prv);

                // Compute the weight between the two elems
                let weight = old_value.decay / decay;

                // Add to the hotness of the new elem
                hotness += Float.fromInt(old_value.amount) * weight;
            };

            builder.add_hot({ hotness; decay; }, timestamp);
            builder.build();
        };

    };

};
