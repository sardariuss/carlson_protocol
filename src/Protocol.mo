import Types "Types";
import Decay "Decay";
import Account "Account";

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
        tx_id: Nat;
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

        // The oldest locks are at the front of the deque (sorted by timestamp)
        var _deque_locked: Deque.Deque<TokensLock> = Deque.empty();

        public func get_locks() : [TokensLock] {
            List.toArray(_deque_locked.0);
        };

        public func lock({
            tx_id: Nat;
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
                for (lock in List.toIter(_deque_locked.0)) {
                    accumulation += lock.rates.growth * Float.fromInt(lock.amount);
                };
                
                // Deduce the time left (in nanoseconds)
                let time_left = Float.fromInt(_params.ns_per_sat) * accumulation / growth;

                {
                    tx_id;
                    from;
                    amount;
                    timestamp;
                    time_left;
                    rates = { growth; decay; };
                };

            };

            // Update the time left for all the previous locks
            var list_locked = List.map(_deque_locked.0, func(lock: TokensLock) : TokensLock {
                let time_left = lock.time_left + (new_lock.rates.decay * Float.fromInt(new_lock.amount) * Float.fromInt(_params.ns_per_sat)) / lock.rates.decay;
                { lock with time_left; };
            });

            // Add the new lock to the list
            list_locked := List.push(new_lock, list_locked);

            // Update the deque
            // Note: it seems that the list that is reversed (where the head is considered the tail) is the first one
            _deque_locked := (List.reverse(list_locked), list_locked);
        };

        // Unlock the tokens if the duration is reached
        public func try_unlock(time: Time) : [TokensLock] {

            let locks : Buffer.Buffer<TokensLock> = Buffer.Buffer(0);

            label endless while true {
                let (lock, deque) = switch(Deque.popFront(_deque_locked)){
                    // Deque is empty
                    case(null) {
                        break endless;
                    };
                    // Deque is not empty
                    case(?pop_front) {
                        pop_front;
                    };
                };

                Debug.print("There is a candidate lock with tx_id=" # debug_show(lock.tx_id));

                // Stop the loop if the duration is not reached yet (the queue is sorted by timestamp)
                if (lock.timestamp + Float.toInt(lock.time_left) > time) {
                    Debug.print("The lock is not expired yet");
                    break endless;
                };

                Debug.print("The lock is expired");

                // Unlock the tokens
                locks.add(lock);
                
                // Do not forget to update the queue!
                _deque_locked := deque;
            };

            Buffer.toArray(locks);
        };

    };

};
