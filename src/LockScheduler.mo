import Types     "Types";
import Decay     "Decay";

import Map       "mo:map/Map";

import Float     "mo:base/Float";
import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";
import Debug     "mo:base/Debug";
import Option    "mo:base/Option";
import Int       "mo:base/Int";

module {

    type Time = Time.Time;

    public type Lock = {
        id: Nat;
        amount: Nat;
        timestamp: Int;
        decay: Float;
        hotness: Float;
        lock_state: LockState;
    };

    public type LockState = {
        #LOCKED;
        #UNLOCKED;
    };
    
    public type DecayParams = {
        lambda: Float;
        shift: Float;
    };

    public class LockScheduler<T>({
        time_init: Time;
        hotness_half_life: Types.Duration;
        get_lock_duration_ns: Float -> Nat;
        to_lock: T -> Lock;
        update_lock: (T, Lock) -> T;
    }){

        let _hotness_decay = Decay.getDecayParameters({
            half_life = hotness_half_life;
            time_init;
        });

        // Creates a new lock with the given id, amount and timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        // Add the lock to the map and return it
        public func new_lock({
            map: Map.Map<Nat, T>;
            id: Nat;
            amount: Nat;
            timestamp: Time;
            new: Lock -> T;
        }) : T {

            // Ensure the lock does not already exist
            if (Map.has(map, Map.nhash, id)) {
                Debug.trap("Lock " # debug_show(id) # " already exists in the map");
            };

            // Ensure the timestamp of the new lock is greater than the timestamp of the last lock
            Option.iterate(Map.peekFront(map), func((_, val): (Nat, T)) {
                if (to_lock(val).timestamp > timestamp) {
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
            //            + (decay_i   / decay_0) * amount_0   + ... + (decay_i * decay_i-1) * amount_i-1
            //            + (decay_i+1 / decay_i) * amount_i+1 + ... + (decay_n / decay_i  ) * amount_n

            let decay = Decay.computeDecay(_hotness_decay, -timestamp);
            var hotness = Float.fromInt(amount);

            // Iterate over the previous locks
            for (elem in Map.vals(map)) {
                
                let previous_lock = to_lock(elem);

                // Compute the weight between the two locks
                let weight = decay / previous_lock.decay;
                
                // Update the hotness of the previous lock
                Map.set(map, Map.nhash, previous_lock.id, update_lock(elem, { previous_lock 
                    with hotness = previous_lock.hotness + Float.fromInt(amount) * weight; }));

                // Add to the hotness of the new lock
                hotness += Float.fromInt(previous_lock.amount) * weight;
            };

            let elem = new({ id; amount; timestamp; decay; hotness; lock_state = #LOCKED;});

            Map.setFront(map, Map.nhash, id, elem);

            elem;
        };

        // Unlock the elements in the map which duration has expired
        // Return the elements that have been unlocked
        public func try_unlock({
            map: Map.Map<Nat, T>;
            time: Time;
        }) : Buffer.Buffer<T> {

            let new_unlocked : Buffer.Buffer<T> = Buffer.Buffer(0);

            label unlock_loop for (val in Map.vals(filter_locked(map))) {
                
                let lock = to_lock(val);

                Debug.print("There is a candidate lock with id=" # debug_show(lock.id));
                
                // Stop the loop if the duration is not reached yet (the locks are added in order of time)
                if (lock.timestamp + get_lock_duration_ns(lock.hotness) > time) {
                    Debug.print("The lock is not expired yet");
                    break unlock_loop;
                };

                Debug.print("The lock is expired");

                // Update the lock state of the element
                let elem = update_lock(val, { lock with lock_state = #UNLOCKED });

                // Update the element in the map
                Map.set<Nat, T>(map, Map.nhash, lock.id, elem);

                // Add the element to the list of new unlocked
                new_unlocked.add(elem);
            };

            new_unlocked;
        };

        func filter_locked(
            map: Map.Map<Nat, T>
        ) : Map.Map<Nat, T> {
            Map.filter<Nat, T>(map, Map.nhash, func((_, val): (Nat, T)) : Bool {
                to_lock(val).lock_state == #LOCKED;
            });
        };

    };

};
