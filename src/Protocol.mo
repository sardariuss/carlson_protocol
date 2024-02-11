import Types "Types";
import Decay "Decay";
import Account "Account";

import Map "mo:map/Map";

import Deque "mo:base/Deque";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

import ICRC1 "mo:icrc1-mo/ICRC1/service";

module {

    type Time = Time.Time;

    public type TokensLock = {
        id: Nat;
        from: ICRC1.Account;
        amount : Nat;
        timestamp: Int;
        time_left: Float; // Floating point to avoid accumulating rounding errors
        rates: { growth: Float; decay: Float; };
    };

    public type ProtocolParams = {
        ns_per_sat: Nat;
        decay_params: Types.DecayParameters;
    };

    public class Protocol(_params: ProtocolParams){

        var _map_locked: Map.Map<Nat, TokensLock> = Map.new();

        public func find_lock(id: Nat) : ?TokensLock {
            Map.get(_map_locked, Map.nhash, id);
        };

        public func num_locks() : Nat {
            Map.size(_map_locked);
        };

        public func lock({
            id: Nat;
            from: ICRC1.Account;
            timestamp: Time;
            amount: Nat;
        }) {

            // Update the total locked
            let new_lock = do {

                // Compute the decays
                let growth = Decay.computeDecay(_params.decay_params, timestamp);
                let decay = Decay.computeDecay(_params.decay_params, -timestamp);

                // Accumulate the increasing decays
                var accumulation = growth * Float.fromInt(amount);
                // Consider all the previous locks to the time left
                for (lock in Map.vals(_map_locked)) {
                    accumulation += lock.rates.growth * Float.fromInt(lock.amount);
                };
                
                // Deduce the time left (in nanoseconds)
                let time_left = Float.fromInt(_params.ns_per_sat) * accumulation / growth;

                {
                    id;
                    from;
                    amount;
                    timestamp;
                    time_left;
                    rates = { growth; decay; };
                };

            };

            // Update the time left for all the previous locks
            _map_locked := Map.map(_map_locked, Map.nhash, func(id: Nat, lock: TokensLock) : TokensLock {
                let time_left = lock.time_left + (new_lock.rates.decay * Float.fromInt(new_lock.amount) * Float.fromInt(_params.ns_per_sat)) / lock.rates.decay;
                { lock with time_left; };
            });

            // @todo: if it is already in the map, should not update time left for previous locks
            if (Map.addFront(_map_locked, Map.nhash, new_lock.id, new_lock) != null) {
                Debug.trap("Lock " # debug_show(new_lock.id) # " already exists in the map");
            };
        };

        // Unlock the tokens if the duration is reached
        public func try_unlock(time: Time) : [TokensLock] {

            let locks : Buffer.Buffer<TokensLock> = Buffer.Buffer(0);

            label endless while true {
                let lock = switch(Map.peek(_map_locked)){
                    // the map is empty
                    case(null) {
                        break endless;
                    };
                    // The map is not empty
                    case(?(_, lock)) {
                        lock;
                    };
                };

                Debug.print("There is a candidate lock with id=" # debug_show(lock.id));

                // Stop the loop if the duration is not reached yet (the map is sorted by timestamp)
                if (lock.timestamp + Float.toInt(lock.time_left) > time) {
                    Debug.print("The lock is not expired yet");
                    break endless;
                };

                Debug.print("The lock is expired");
               
                // Remove the lock from the map
                Map.delete(_map_locked, Map.nhash, lock.id);

                // Add the lock to the list to return
                locks.add(lock);
            };

            Buffer.toArray(locks);
        };

    };

};
