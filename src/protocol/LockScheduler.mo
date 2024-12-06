import Types "Types";
import Timeline "utils/Timeline";

import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type LockRegister = Types.LockRegister;

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        lock_register: LockRegister;
        update_lock_duration: (YesNoBallot, Time) -> ();
        about_to_add: (YesNoBallot, Time) -> ();
        about_to_remove: (YesNoBallot, Time) -> ();
    }) {

        // add
        public func add(ballot: YesNoBallot, time: Time) {
            
            update_lock_duration(ballot, time);
            let lock = get_lock(ballot);
            let { locks; total_amount; } = lock_register;

            if (not BTree.has(locks, compare_locks, lock)){
                about_to_add(ballot, ballot.timestamp);
                ignore BTree.insert(locks, compare_locks, lock, ballot);
                Timeline.add(total_amount, time, Timeline.current(total_amount) + ballot.amount);
            };
        };

        // update
        public func update(ballot: YesNoBallot, time: Time) {
            
            let { locks; } = lock_register;

            // Only update the lock if it is already there
            switch(BTree.delete(locks, compare_locks, get_lock(ballot))) {
                case(null) {};
                case(_) {
                    update_lock_duration(ballot, time);
                    ignore BTree.insert(locks, compare_locks, get_lock(ballot), ballot);
                };
            };
        };

        // try_unlock
        public func try_unlock(time: Time) {
            let { locks; total_amount; } = lock_register;

            while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, ballot)) {
                        if (lock.release_date > time) { return; };
                        about_to_remove(ballot, lock.release_date);
                        ignore BTree.delete(locks, compare_locks, lock);
                        Timeline.add(total_amount, lock.release_date, Timeline.current(total_amount) - ballot.amount);
                    };
                };
            };
        };

        func get_lock(ballot: YesNoBallot) : Lock {
            { release_date = ballot.release_date; id = ballot.ballot_id; };
        };

    };

};