import TimeoutCalculator "../TimeoutCalculator";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Buffer            "mo:base/Buffer";

module {
    
    type Time = Int;
    type ITimeoutCalculator = TimeoutCalculator.ITimeoutCalculator;

    public type LockRegister<V> = {
        var index: Nat;
        map: Map.Map<Nat, V>;
        locks: Set.Set<Nat>;
    };

    type SetFromSlice<K, V, S> = (map: Map.Map<K, V>, hash: Map.HashUtils<K>, key: K, value: S) -> V;
    
    // @todo: have a class Register<K> and add K argument
    public class LockScheduler<V, S>({
        timeout_calculator: V -> Time;
        set_from_slice: SetFromSlice<Nat, V, S>;
    }){

        public func add_lock({
            register: LockRegister<V>;
            lock: S;
        }) : (Nat, V) {

            let key = register.index;
            register.index := register.index + 1;

            let elem = set_from_slice(register.map, Map.nhash, key, lock);
            Set.add(register.locks, Map.nhash, key);

            (key, elem);
        };

        public func try_unlock({
            register: LockRegister<V>;
            time: Time;
        }) : Buffer.Buffer<(Nat, V)>{

            let buffer = Buffer.Buffer<(Nat, V)>(0);

            for ((key, elem) in Map.entries(register.map)) {
                
                if (timeout_calculator(elem) <= time) {
                    buffer.add((key, elem));
                    Set.delete(register.locks, Map.nhash, key);
                };
            };

            buffer;
        };

    };
};