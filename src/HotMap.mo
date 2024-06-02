import Decay   "Decay";
import WMap    "utils/WMap";

import Map     "mo:map/Map";

import Float   "mo:base/Float";
import Int     "mo:base/Int";
import Option  "mo:base/Option";
import Iter    "mo:base/Iter";

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

    type ToElem<V, H> = H -> V;

    type ToHot<V, H> = {
        elem: V;
        decay: Float;
        hotness: Float;
    } -> H;


    type UpdateHot<H> = {
        elem: H;
        hotness: Float;
    } -> H;

    public class HotMap<K, V, H>({
        map: Map<K, H>;
        hash: Map.HashUtils<K>;
        get_inputs: GetInputs<V>;
        get_outputs: GetOutputs<H>;
        to_hot: ToHot<V, H>;
        to_elem: ToElem<V, H>;
        update_hotness: UpdateHot<H>;
        decay_model: DecayModel;
    }){

        let _wmap = WMap.WMap<K, H>(map, hash);

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
            Option.iterate(_wmap.peek(), func((_, previous) : (K, H)) {
                assert(get_outputs(previous).timestamp < timestamp);
            });

            let decay = decay_model.computeDecay(timestamp);

            var hotness : Float = 0;

            // Iterate over the previous elements
            for ((prev_k, prv_v) in _wmap.entries()) {

                let previous = get_outputs(prv_v);

                // Compute the weight between the two locks
                let weight = previous.decay / decay;

                // Add to the hotness of the new lock
                hotness += previous.amount * weight;

                // Add to the hotness of the previous lock
                _wmap.set(prev_k, update_hotness({ 
                    elem = prv_v;
                    hotness = previous.hotness + amount * weight; 
                }));
            };

            _wmap.set(k, to_hot({ elem = v; decay; hotness; }));
        };

        public func get(key: K): ?V {
            Option.map(_wmap.get(key), func(h: H) : V { to_elem(h);});
        };
            
        public func has(key: K): Bool {
            _wmap.has(key);
        };
            
        public func put(key: K, value: V): ?V {
            let old = get(key);
            set(key, value);
            old;
        };
            
        public func remove(key: K): ?V {
            Option.map(_wmap.remove(key), func(h: H) : V { to_elem(h);});
        };
            
        public func delete(key: K) {
            _wmap.delete(key);
        };
            
        public func filter(fn: (key: K, value: V) -> Bool): Map<K, V> {
            _wmap.filter(fn);
        };
            
        public func keys(): Iter.Iter<K> {
            _wmap.keys();
        };
            
        public func vals(): Iter.Iter<V> {
            _wmap.vals();
        };
            
        public func entries(): Iter.Iter<(K, V)> {
            _wmap.entries();
        };
            
        public func forEach(fn: (key: K, value: V) -> ()) {
            _wmap.forEach(fn);
        };
            
        public func some(fn: (key: K, value: V) -> Bool): Bool {
            _wmap.some(fn);
        };
            
        public func every(fn: (key: K, value: V) -> Bool): Bool {
            _wmap.every(fn);
        };
            
        public func find(fn: (key: K, value: V) -> Bool): ?(K, V) {
            _wmap.find(fn);
        };
            
        public func findDesc(fn: (key: K, value: V) -> Bool): ?(K, V) {
            _wmap.findDesc(fn);
        };
            
        public func clear() {
            _wmap.clear();
        };
            
        public func size(): Nat {
            _wmap.size();
        };
        
    };

}