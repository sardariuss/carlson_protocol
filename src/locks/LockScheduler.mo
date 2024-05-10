import Decay     "../Decay";

import Map       "mo:map/Map";

import Float     "mo:base/Float";
import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";
import Debug     "mo:base/Debug";
import Option    "mo:base/Option";
import Int       "mo:base/Int";

module {

    type Time = Time.Time;
    type DecayModel = Decay.DecayModel;

    public type Lock<T> = {
        id: Nat;
        amount: Nat;
        timestamp: Int;
        decay: Float;
        hotness: Float;
        data: T;
    };
    
    public class LockScheduler<T>({
        decay_model: DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }){

        // Creates a new lock with the given id, amount and timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        // Add the lock to the map and return it
        public func new_lock({
            locks: Map.Map<Nat, Lock<T>>;
            id: Nat;
            amount: Nat;
            timestamp: Time;
            data: T;
        }) {

            // Ensure the lock does not already exist
            if (Map.has(locks, Map.nhash, id)) {
                Debug.trap("Lock " # debug_show(id) # " already exists in the map");
            };

            // Ensure the timestamp of the new lock is greater than the timestamp of the last lock
            Option.iterate(Map.peek(locks), func((_, lock): (Nat, Lock<T>)) {
                if (lock.timestamp > timestamp) {
                    Debug.trap("The timestamp of the last lock is greater than the timestamp of the new lock");
                };
            });

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
            for (previous_lock in Map.vals(locks)) {

                // Compute the weight between the two locks
                let weight = previous_lock.decay / decay;
                
                // Update the hotness of the previous lock
                Map.set(locks, Map.nhash, previous_lock.id, { previous_lock 
                    with hotness = previous_lock.hotness + Float.fromInt(amount) * weight; });

                // Add to the hotness of the new lock
                hotness += Float.fromInt(previous_lock.amount) * weight;
            };

            Map.set(locks, Map.nhash, id, { id; amount; timestamp; decay; hotness; data; });
        };

        // Unlock the elements in the map which duration has expired
        // Return the elements that have been unlocked
        public func try_unlock(
            locks: Map.Map<Nat, Lock<T>>,
            time: Time,
        ) : Buffer.Buffer<Lock<T>> {

            let unlocked : Buffer.Buffer<Lock<T>> = Buffer.Buffer(0);

            label endless_loop loop {

                let lock = switch(Map.peek(locks)){
                    case(null) { break endless_loop; };
                    case(?(_, l)) { l; };
                };

                //Debug.print("There is a candidate lock with id=" # debug_show(lock.id));

                // Stop the loop if the duration is not reached yet (the locks are added in order of time)
                if (lock.timestamp + get_lock_duration_ns(lock.hotness) > time) {
                    //Debug.print("The lock is not expired yet");
                    break endless_loop;
                };

                //Debug.print("The lock is expired");

                // Add the element to the list of new unlocked
                unlocked.add(lock);

                // Remove the element in the map
                Map.delete(locks, Map.nhash, lock.id);
            };

            unlocked;
        };

    };

};
