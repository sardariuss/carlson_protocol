import Types "Types";
import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Option "mo:base/Option";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler2({
        locks: BTree<Lock, YesNoBallot>;
        update_lock_duration: (YesNoBallot, Time) -> ();
        about_to_add: (YesNoBallot, Time) -> ();
        about_to_remove: (YesNoBallot, Time) -> ();
    }) {

        // add
        public func add(ballot: YesNoBallot, time: Time) {
            update_lock_duration(ballot, time);
            let lock = get_lock(ballot);
            if (not BTree.has(locks, compare_locks, lock)){
                about_to_add(ballot, ballot.timestamp);
                ignore BTree.insert(locks, compare_locks, lock, ballot);
            };
        };

        // update
        public func update(ballot: YesNoBallot, time: Time) {
            // Only perform the update the lock duration if the lock is active (i.e. present in the locks BTree)
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
            while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, ballot)) {
                        if (lock.release_date > time) { return; };
                        about_to_remove(ballot, lock.release_date);
                        ignore BTree.delete(locks, compare_locks, lock);
                    };
                };
            };
        };

        func get_lock(ballot: YesNoBallot) : Lock {
            { release_date = ballot.release_date; id = ballot.ballot_id; };
        };

    };

};