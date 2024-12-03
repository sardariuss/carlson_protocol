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
        on_lock_added: (Lock, YesNoBallot) -> ();
        on_lock_removed: (Lock, YesNoBallot) -> ();
    }) {

        // add
        public func add({unlock_time: Time; id: UUID; ballot: YesNoBallot}) {
            let lock = { unlock_time; id; };
            switch(BTree.insert(locks, compare_locks, lock, ballot)){
                case(null) { on_lock_added(lock, ballot); };
                case(_) {};
            };
        };

        // remove
        public func remove({unlock_time: Time; id: UUID}) {
            let lock = { unlock_time; id; };
            switch(BTree.delete(locks, compare_locks, lock)){
                case(null) {};
                case(?ballot) { on_lock_removed(lock, ballot); };
            };
        };

        // update
        public func update({id: UUID; old_time: Time; new_time: Time; ballot: YesNoBallot; }) {
            remove({unlock_time = old_time; id});
            add({unlock_time = new_time; id; ballot; });
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