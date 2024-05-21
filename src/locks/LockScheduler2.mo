import Decay     "../Decay";

import Float     "mo:base/Float";
import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";
import Int       "mo:base/Int";
import Iter      "mo:base/Iter";

module {

    type Time = Time.Time;
    type DecayModel = Decay.DecayModel;
    type Iter<T> = Iter.Iter<T>;

    public type Lock = {
        amount: Nat;
        timestamp: Int;
        decay: Float;
        hotness: Float;
        expiration: Time;
    };
    
    public class LockScheduler({
        decay_model: DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }){

        // Creates a new lock with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        // @todo: shall we return the date of the earliest expiration?
        public func new_lock({
            iter: Iter<(Nat, Lock)>;
            update: (Nat, Lock) -> ();
            add: Lock -> Nat;
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
            for ((id, previous_lock) in iter) {

                // Compute the weight between the two locks
                let weight = previous_lock.decay / decay;
                
                // Update the hotness of the previous lock
                let previous_hotness = previous_lock.hotness + Float.fromInt(amount) * weight;
                let previous_expiration = previous_lock.timestamp + get_lock_duration_ns(previous_hotness);
                update(id, { previous_lock with hotness = previous_hotness; expiration = previous_expiration; });

                // Add to the hotness of the new lock
                hotness += Float.fromInt(previous_lock.amount) * weight;
            };

            add({ amount; timestamp; decay; hotness; expiration = timestamp + get_lock_duration_ns(hotness); });
        };

        // Remove the locks that have expired
        public func remove_locks(
            time: Time,
            iter: Iter<(Nat, Lock)>,
            remove_lock: Nat -> (),
        ) {

            for ((id, lock) in iter) {
                if (lock.expiration <= time) {
                    remove_lock(id);
                };
            };
        };

    };

};
