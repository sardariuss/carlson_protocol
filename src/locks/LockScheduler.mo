import HotMap "HotMap";

import Map "mo:map/Map";
import Set "mo:map/Set";

import Buffer "mo:base/Buffer";

module {
    
    type Time = Int;

    public type LockRegister<V> = {
        var index: Nat;
        map: Map.Map<Nat, V>;
        locks: Set.Set<Nat>;
    };
    
    public class LockScheduler<V>({
        hot_map: HotMap.HotMap<Nat, V>;
        unlock_condition: (V, Time) -> Bool;
    }){

        public func add_lock({
            register: LockRegister<V>;
            new: HotMap.HotInfo -> V;
            amount: Nat;
            timestamp: Time;
        }) : (Nat, V) {

            let key = register.index;
            register.index := register.index + 1;

            let elem = hot_map.add_new({ map = register.map; key; new; amount; timestamp; });
            Set.add(register.locks, Map.nhash, key);

            (key, elem);
        };

        public func try_unlock({
            register: LockRegister<V>;
            time: Time;
        }) : Buffer.Buffer<(Nat, V)>{

            let buffer = Buffer.Buffer<(Nat, V)>(0);

            for ((key, elem) in Map.entries(register.map)) {
                
                if (unlock_condition(elem, time)) {
                    buffer.add((key, elem));
                    Set.delete(register.locks, Map.nhash, key);
                };
            };

            buffer;
        };

    };
};