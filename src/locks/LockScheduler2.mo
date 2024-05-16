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
    };
    
    public class LockScheduler({
        decay_model: DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }){

        // Creates a new lock with the given amount and timestamp
        // Deduce the decay from the given timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        public func new_lock({
            lock_iter: Iter<(Nat, Lock)>;
            lock_update: (Nat, Lock) -> ();
            amount: Nat;
            timestamp: Time;
        }) : Lock {

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
            for ((id, previous_lock) in lock_iter) {

                // Compute the weight between the two locks
                let weight = previous_lock.decay / decay;
                
                // Update the hotness of the previous lock
                lock_update(id, { previous_lock 
                    with hotness = previous_lock.hotness + Float.fromInt(amount) * weight; });

                // Add to the hotness of the new lock
                hotness += Float.fromInt(previous_lock.amount) * weight;
            };

            { amount; timestamp; decay; hotness; };
        };

        // Retrieve locks which duration has expired
        public func try_unlock(
            lock_iter: Iter<(Nat, Lock)>,
            time: Time,
        ) : Buffer.Buffer<(Nat, Lock)> {

            let unlocked : Buffer.Buffer<(Nat, Lock)> = Buffer.Buffer(0);

            for ((id, lock) in lock_iter) {
                if (lock.timestamp + get_lock_duration_ns(lock.hotness) <= time) {
                    unlocked.add((id, lock));
                };
            };

            unlocked;
        };

    };

};
