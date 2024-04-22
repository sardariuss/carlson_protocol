import Types     "Types";
import Duration  "Duration";
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
        hotness: Float;
        rates: { 
            growth: Float;
            decay: Float; 
        };
    };
    
    public type DecayParams = {
        lambda: Float;
        shift: Float;
    };

    public class LockScheduler<T>({
        time_init: Time;
        hotness_half_life: Types.Duration;
        nominal_lock_duration: Types.Duration;
        to_lock: T -> Lock;
    }){

        // Attributes
        let _hotness_decay = Decay.getDecayParameters({
            half_life = hotness_half_life;
            time_init;
        });
        let _nominal_lock_duration_ns = Float.fromInt(Duration.toTime(nominal_lock_duration));

        // Creates a new lock with the given id, amount and timestamp
        // Deduce the hotness of the lock from the previous locks
        // Update the hotness of the previous locks
        // Add the lock to the map and return it
        public func new_lock({
            map: Map.Map<Nat, T>;
            id: Nat;
            amount: Nat;
            timestamp: Time;
            from_lock: Lock -> T;
        }) : T {

            // @todo: assert the timestamp of the last lock is less than the new one

            // Create the new entry
            let new : Lock = do {

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
                
                let growth = Decay.computeDecay(_hotness_decay, timestamp);
                let decay = Decay.computeDecay(_hotness_decay, -timestamp);

                // Compute the hotness
                var hotness : Float = 0;
                for (val in Map.vals(map)) {
                    let lock = to_lock(val);
                    hotness += lock.rates.growth * Float.fromInt(lock.amount);
                };
                hotness /= growth;
                hotness += Float.fromInt(amount);

                {
                    id;
                    amount;
                    timestamp;
                    hotness;
                    rates = { growth; decay; };
                };
            };

            // Add the lock to the map
            if (Option.isSome(Map.addFront(map, Map.nhash, id, from_lock(new)))) {
                Debug.trap("Lock " # debug_show(id) # " already exists in the map");
            };

            // Update the hotness for all the previous locks
            label update_loop for (val in Map.vals(map)) {
                let lock = to_lock(val);

                // If the lock is the new one, skip it
                if (lock.id == id){
                    continue update_loop;
                };

                let hotness = lock.hotness + Float.fromInt(new.amount) * new.rates.decay / lock.rates.decay;
                Map.set(map, Map.nhash, lock.id, from_lock({ lock with hotness; }));
            };

            from_lock(new);
        };

        // Remove the locks from the map which duration has expired
        // Return the removed locks
        public func try_unlock({
            map: Map.Map<Nat, T>;
            time: Time
        }) : Buffer.Buffer<T> {

            let removed : Buffer.Buffer<T> = Buffer.Buffer(0);

            label endless_loop while true {
                let { id; timestamp; hotness; } = switch(Map.peek(map)){
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

                // Stop the loop if the duration is not reached yet (the locks are added in order of time)
                if (timestamp + get_lock_duration_ns(hotness) > time) {
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


        // The time dilation curve is responsible for scaling the time left of each lock to prevent
        // absurd locking times (e.g. 10 seconds or 100 years).
        // It is defined as a power function of the hotness so that the duration is doubled for each 
        // order of magnitude of hotness:
        //      duration = a * hotness ^ b where 
        // where:
        //      a is the duration for a hotness of 1
        //      b = ln(2) / ln(10)
        //
        //                                                   ································
        //  lock_time                        ················
        //      ↑                    ········
        //        → hotness      ····
        //                     ··
        //                    ·
        // 
        func get_lock_duration_ns(hotness: Float) : Nat {
            let scale_factor = Float.log(2.0) / Float.log(10.0);
            Int.abs(Float.toInt(_nominal_lock_duration_ns * Float.pow(hotness, scale_factor)));
        };

    };

};
