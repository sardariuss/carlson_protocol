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
        switch(Int.compare(a.unlock_time, b.unlock_time)){
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
        public func update(old_ballot: YesNoBallot, new_ballot: YesNoBallot, time: Time) {
            // Only perform the update if the old lock is present in the tree
            switch(BTree.delete(locks, compare_locks, get_lock(old_ballot))) {
                case(null) {};
                case(_) {
                    update_lock_duration(new_ballot, time);
                    ignore BTree.insert(locks, compare_locks, get_lock(new_ballot), new_ballot);
                };
            };
        };

        // try_unlock
        public func try_unlock(time: Time) {
            while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, ballot)) {
                        if (lock.unlock_time > time) { return; };
                        about_to_remove(ballot, lock.unlock_time);
                        ignore BTree.delete(locks, compare_locks, lock);
                    };
                };
            };
        };

        func get_lock(ballot: YesNoBallot) : Lock {
            { unlock_time = 0; /*ballot.unlock_time*/ id = ballot.ballot_id; };
        };

    };

};