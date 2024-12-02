import Types "Types";
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

    func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.unlock_time, b.unlock_time)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.ref, b.ref); };
        };
    };

    public class LockScheduler2({
        locks: BTree<Lock, ()>;
        on_lock_added: Lock -> ();
        on_lock_removed: Lock -> ();
    }) {

        // add
        public func add(lock: Lock) {
            switch(BTree.insert(locks, compare_locks, lock, ())){
                case(null) { on_lock_added(lock); };
                case(_) {};
            };
        };

        // remove
        public func remove(lock: Lock) {
            switch(BTree.delete(locks, compare_locks, lock)){
                case(null) {};
                case(_) { on_lock_removed(lock); };
            };
        };

        // update
        public func update({ref: UUID; old_time: Time; new_time: Time; }) {
            add({unlock_time = old_time; ref});
            remove({unlock_time = new_time; ref});
        };

        // try_unlock
        public func try_unlock(time: Time) {
            while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, _)) {
                        if (lock.unlock_time > time) { return; };
                        remove(lock);
                    };
                };
            };
        };

    };

};