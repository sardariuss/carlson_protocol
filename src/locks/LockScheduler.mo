import Decay     "../Decay";

import Map       "mo:map/Map";

import Float     "mo:base/Float";
import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";
import Int       "mo:base/Int";
import Iter      "mo:base/Iter";

module {

    type Time = Time.Time;
    type DecayModel = Decay.DecayModel;
    type Iter<T> = Iter.Iter<T>;

    public type LockInfo = {
        amount: Nat;
        timestamp: Int;
        decay: Float;
        hotness: Float;
        state: LockState;
    };

    public type LockState = {
        #LOCKED: { until: Time; };
        #UNLOCKED: { since: Time; };
    };
    
    public class LockScheduler<T>({
        decay_model: DecayModel;
        get_lock_duration_ns: Float -> Nat;
        get_lock: T -> LockInfo;
        update_lock: (T, LockInfo) -> T;
    }){

        // Creates a new lock with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        // @todo: shall we return the date of the earliest until?
        public func new_lock({
            map: Map.Map<Nat, T>;
            new: LockInfo -> (Nat, T);
            amount: Nat;
            timestamp: Time;
        }) : Nat {

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

            let decay = decay_model.computeDecay(timestamp);

            var hotness = Float.fromInt(amount);

            // Iterate over the previous locks
            label locked for ((id, prv) in Map.entries(map)) {

                let prev_lock = get_lock(prv);

                // Ensure the timestamp of the previous lock is smaller than the given timestamp
                assert(prev_lock.timestamp < timestamp);

                // Compute the weight between the two locks
                let weight = prev_lock.decay / decay;

                // Add to the hotness of the new lock
                hotness += Float.fromInt(prev_lock.amount) * weight;
                
                // Update the hotness of the previous lock if it is still locked
                switch(prev_lock.state){
                    case(#LOCKED({ until })) {
                        let prv_hotness = prev_lock.hotness + Float.fromInt(amount) * weight;
                        let prv_until = prev_lock.timestamp + get_lock_duration_ns(prv_hotness);
                        Map.set(map, Map.nhash, id, update_lock(prv, { 
                            prev_lock with 
                            hotness = prv_hotness;
                            state = #LOCKED { until = prv_until; };
                        }));
                    };
                    case(_) {};
                };
            };

            // Create the new lock
            let (id, new_elem) = new({ 
                amount; 
                timestamp;
                decay; 
                hotness;
                state = #LOCKED { until = timestamp + get_lock_duration_ns(hotness); };
            });
            Map.set(map, Map.nhash, id, new_elem);
            id;
        };

        // Unlock the expired locks
        public func try_unlock(
            map: Map.Map<Nat, T>,
            time: Time,
        ) : Buffer.Buffer<(Nat, T)>{

            let buffer = Buffer.Buffer<(Nat, T)>(0);

            for ((id, elem) in Map.entries(map)) {
                let lock = get_lock(elem);

                switch(lock.state){
                    case(#LOCKED({ until })) {
                        if (until <= time) {
                            let update = update_lock(elem, { lock with state = #UNLOCKED { since = time; } });
                            Map.set(map, Map.nhash, id, update);
                            buffer.add((id, update));
                        };
                    };
                    case(_) {};
                };
            };

            buffer;
        };

    };

};
