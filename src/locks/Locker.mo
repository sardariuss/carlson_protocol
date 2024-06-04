import IMap      "../map/IMap";

import Time      "mo:base/Time";
import Buffer    "mo:base/Buffer";

module {

    type Time = Time.Time;
    type IMapComposite<K, V, T> = IMap.IMapComposite<K, V, T>;
    type IMap<K, V> = IMap.IMap<K, V>;

    public type LockState = {
        #LOCKED: { since: Time; };
        #UNLOCKED: { since: Time; };
    };
    
    public class Locker<V>({
        get_lock: V -> LockState;
        update_lock: (V, LockState) -> V;
        unlock_condition: (V, Time) -> Bool;
    }){

        // Add a lock to the map, and return the id and the element
        public func add_lock<T>({
            map_composite: IMapComposite<Nat, V, T>;
            key: Nat;
            new: LockState -> T;
            time: Time;
        }) : (Nat, V) {
            let elem = new(#LOCKED{ since = time });
            (key, map_composite.composite_set(key, elem));
        };

        // Unlock all locks that satisfy the condition
        public func try_unlock({
            map: IMap<Nat, V>;
            time: Time;
        }) : Buffer.Buffer<(Nat, V)>{

            let buffer = Buffer.Buffer<(Nat, V)>(0);

            for ((id, elem) in map.entries()) {
                switch(get_lock(elem)){
                    case(#LOCKED(_)) {
                        if (unlock_condition(elem, time)){
                            let update = update_lock(elem, #UNLOCKED{ since = time });
                            map.set(id, update);
                            buffer.add((id, update));
                        };
                    };
                    case(_) {};
                };
            };

            buffer;
        };

    };

};
