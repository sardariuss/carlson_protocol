import Types "Types";
import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    
    public type Lock = {
        time: Time;
        ref: UUID;
    };

    public class LockScheduler2({
        locks: BTree<Lock, ()>;
        compare: (Lock, Lock) -> Order;
        on_lock_added: Lock -> ();
        on_lock_removed: Lock -> ();
    }) {

        // add
        public func add(lock: Lock) {
            switch(BTree.insert(locks, compare, lock, ())){
                case(null) { on_lock_added(lock); };
                case(_) {};
            };
        };

        // remove
        public func remove(lock: Lock) {
            switch(BTree.delete(locks, compare, lock)){
                case(null) {};
                case(_) { on_lock_removed(lock); };
            };
        };

        // update
        public func update({old_time: Time; new_time: Time; ref: UUID}) {
            add({time = old_time; ref});
            remove({time = new_time; ref});
        };

        // try_unlock
        public func try_unlock(time: Time) {
            while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, _)) {
                        if (lock.time > time) { return; };
                        remove(lock);
                    };
                };
            };
        };

    };

};