import Interfaces "../Interfaces";

import Float      "mo:base/Float";
import Result     "mo:base/Result";
import Iter       "mo:base/Iter";

module {

    type Time = Int;
    type IDecayModel = Interfaces.IDecayModel;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Iter<T> = Iter.Iter<T>;

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
        var hotness: Float;
    };

    public type HotElem = HotInput and HotOutput;

    public type UpdateHotness<V> = {
        v: V;
        hotness: Float;
        time: Time;
    } -> ();
    
    public class HotMap<K, V>({
        decay_model: IDecayModel;
        get_elem: V -> HotElem;
        update_hotness: UpdateHotness<V>;
    }){

        // Creates a new elem with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the elem from the previous elems
        // Update the hotness of the previous elems
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
        public func add_new({
            iter: Iter<V>;
            builder: IHotElemBuilder<V>;
            args: HotInput;
            update_map: Bool;
        }) : V {

            let { amount; timestamp; } = args;
            let decay = decay_model.compute_decay(timestamp);
            var hotness = Float.fromInt(amount);

            // Iterate over the previous elems
            for (v in iter) {

                let prev_elem = get_elem(v);

                // Compute the weight between the two elems
                let weight = prev_elem.decay / decay;

                hotness += Float.fromInt(prev_elem.amount) * weight;

                if (update_map) {
                    // Add to the hotness of the new elem
                    let prev_hotness = prev_elem.hotness + Float.fromInt(amount) * weight;
                    
                    // Update the hotness of the previous elem
                    update_hotness({ v; hotness = prev_hotness; time = timestamp; });
                };
            };

            // Return the new elem
            builder.add_hot({ var hotness = hotness; decay; }, timestamp);
            builder.build();
        };

    };

};
