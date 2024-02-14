import Types     "Types";
import Decay     "Decay";
import Account   "Account";
import Ballot    "Ballot";

import Map       "mo:map/Map";

import Nat       "mo:base/Nat";
import Float     "mo:base/Float";
import Int       "mo:base/Int";
import Time      "mo:base/Time";
import Principal "mo:base/Principal";
import Nat64     "mo:base/Nat64";
import Buffer    "mo:base/Buffer";
import Debug     "mo:base/Debug";

module {

    type Time = Time.Time;

    type TokensLock = Types.TokensLock;
    type LocksParams = Types.LocksParams;

    public class Locks({
        lock_params: LocksParams;
        locks: Map.Map<Nat, TokensLock>;
    }){

        public func find_lock(tx_id: Nat) : ?TokensLock {
            Map.get(locks, Map.nhash, tx_id);
        };

        public func num_locks() : Nat {
            Map.size(locks);
        };

        public func add_lock({
            tx_id: Nat;
            from: Types.Account;
            contest_factor: Float;
            timestamp: Time;
            ballot: Types.Ballot;
        }) {

            // Update the total locked
            let new_lock = do {

                // Compute the decays
                let growth = Decay.computeDecay(lock_params.decay_params, timestamp);
                let decay = Decay.computeDecay(lock_params.decay_params, -timestamp);

                // Accumulate the increasing decays
                var accumulation = growth * Float.fromInt(Ballot.get_amount(ballot));
                // Consider all the previous locks to the time left
                for (lock in Map.vals(locks)) {
                    accumulation += lock.rates.growth * Float.fromInt(Ballot.get_amount(lock.ballot));
                };
                
                // Deduce the time left (in nanoseconds)
                let time_left = Float.fromInt(lock_params.ns_per_sat) * accumulation / growth;

                {
                    tx_id;
                    from;
                    ballot;
                    contest_factor;
                    timestamp;
                    time_left;
                    rates = { growth; decay; };
                };

            };

            // Add the lock to the map
            if (Map.addFront(locks, Map.nhash, new_lock.tx_id, new_lock) != null) {
                Debug.trap("Lock " # debug_show(new_lock.tx_id) # " already exists in the map");
            };

            // Update the time left for all the previous locks
            for (lock in Map.vals(locks)) {
                if (lock.tx_id != new_lock.tx_id){
                    let time_left = lock.time_left 
                        + (new_lock.rates.decay * Float.fromInt(Ballot.get_amount(new_lock.ballot)) 
                            * Float.fromInt(lock_params.ns_per_sat)) 
                            / lock.rates.decay;
                    Map.set(locks, Map.nhash, lock.tx_id, { lock with time_left; });
                };
            };
        };

        // Unlock the tokens if the duration is reached
        public func try_unlock(time: Time) : Buffer.Buffer<TokensLock> {

            let unlocks : Buffer.Buffer<TokensLock> = Buffer.Buffer(0);

            label endless while true {
                let lock = switch(Map.peek(locks)){
                    // the map is empty
                    case(null) {
                        break endless;
                    };
                    // The map is not empty
                    case(?(_, lock)) {
                        lock;
                    };
                };

                Debug.print("There is a candidate lock with id=" # debug_show(lock.tx_id));

                // Stop the loop if the duration is not reached yet (the map is sorted by timestamp)
                if (lock.timestamp + Float.toInt(lock.time_left) > time) {
                    Debug.print("The lock is not expired yet");
                    break endless;
                };

                Debug.print("The lock is expired");
               
                // Remove the lock from the map
                Map.delete(locks, Map.nhash, lock.tx_id);

                // Add the lock to the list to return
                unlocks.add(lock);
            };

            unlocks;
        };

    };

};
