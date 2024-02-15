import Decay     "Decay";

import Map       "mo:map/Map";

import Float     "mo:base/Float";
import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";
import Debug     "mo:base/Debug";
import Option    "mo:base/Option";

module {

    type Time = Time.Time;

    public type Lock = {
        id: Nat;
        amount: Nat;
        timestamp: Int;
        time_left: Float; // Floating point to avoid accumulating rounding errors
        rates: { 
            growth: Float;
            decay: Float; 
        };
    };
    
    public type Params = {
        ns_per_sat: Nat;
        decay_params: {
            lambda: Float;
            shift: Float;
        };
    };

    public class LockScheduler<T>({
        lock_params: Params;
        to_lock: T -> Lock;
    }){

        public func new_lock({
            map: Map.Map<Nat, T>;
            id: Nat;
            amount: Nat;
            timestamp: Time;
            from_lock: Lock -> T;
        }) : T {

            // Create the new entry
            let new : Lock = do {

                // Compute the decays
                let growth = Decay.computeDecay(lock_params.decay_params, timestamp);
                let decay = Decay.computeDecay(lock_params.decay_params, -timestamp);

                // Accumulate the increasing decays
                var accumulation = growth * Float.fromInt(amount);
                // Consider all the previous locks to the time left
                for (val in Map.vals(map)) {
                    let lock = to_lock(val);
                    accumulation += lock.rates.growth * Float.fromInt(lock.amount);
                };
                
                // Deduce the time left (in nanoseconds)
                let time_left = Float.fromInt(lock_params.ns_per_sat) * accumulation / growth;

                {
                    id;
                    amount;
                    timestamp;
                    time_left;
                    rates = { growth; decay; };
                };
            };

            // Add the lock to the map
            if (Option.isSome(Map.addFront(map, Map.nhash, id, from_lock(new)))) {
                Debug.trap("Lock " # debug_show(id) # " already exists in the map");
            };

            // Update the time left for all the previous locks
            label update_loop for (val in Map.vals(map)) {
                let lock = to_lock(val);

                // If the lock is the new one, skip it
                if (lock.id == id){
                    continue update_loop;
                };

                // Update the time left
                let time_left = lock.time_left 
                    + (new.rates.decay * Float.fromInt(new.amount) 
                        * Float.fromInt(lock_params.ns_per_sat)) 
                        / lock.rates.decay;
                Map.set(map, Map.nhash, lock.id, from_lock({ lock with time_left; }));
            };

            from_lock(new);
        };

        // Unlock the tokens if the duration is reached
        public func try_unlock({
            map: Map.Map<Nat, T>;
            time: Time
        }) : Buffer.Buffer<T> {

            let removed : Buffer.Buffer<T> = Buffer.Buffer(0);

            label endless_loop while true {
                let { id; timestamp; time_left; } = switch(Map.peek(map)){
                    // The map is empty
                    case(null) {
                        break endless_loop;
                    };
                    // The map is not empty
                    case(?(_, val)) {
                        to_lock(val);
                    };
                };

                Debug.print("There is a candidate lock with id=" # debug_show(id));

                // Stop the loop if the duration is not reached yet (the map is sorted by timestamp)
                if (timestamp + Float.toInt(time_left) > time) {
                    Debug.print("The lock is not expired yet");
                    break endless_loop;
                };

                Debug.print("The lock is expired");
               
                // Remove the lock from the map
                switch(Map.remove(map, Map.nhash, id)){
                    case(?val) {
                        removed.add(val);
                    };
                    case(null) {
                        Debug.trap("The lock " # debug_show(id) # " could not be removed in the map");
                    };
                };
            };

            removed;
        };

    };

};
