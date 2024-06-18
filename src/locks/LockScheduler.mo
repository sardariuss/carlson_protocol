import HotMap            "HotMap";
import TimeoutCalculator "../TimeoutCalculator";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Buffer            "mo:base/Buffer";

module {
    
    type Time = Int;
    type ITimeoutCalculator = TimeoutCalculator.ITimeoutCalculator;

    public type ILockInfoBuilder<T> = HotMap.IHotInfoBuilder<T>;

    public type LockRegister<V> = {
        var index: Nat;
        map: Map.Map<Nat, V>;
        locks: Set.Set<Nat>;
    };
    
    public class LockScheduler<V>({
        hot_map: HotMap.HotMap<Nat, V>;
        timeout_calculator: ITimeoutCalculator;
        hot_info: V -> HotMap.HotInfo;
    }){

        public func add_lock({
            register: LockRegister<V>;
            builder: ILockInfoBuilder<V>;
            amount: Nat;
            timestamp: Time;
        }) : (Nat, V) {

            let key = register.index;
            register.index := register.index + 1;

            let elem = hot_map.add_new({ map = register.map; key; builder; amount; timestamp; });
            Set.add(register.locks, Map.nhash, key);

            (key, elem);
        };

        public func try_unlock({
            register: LockRegister<V>;
            time: Time;
        }) : Buffer.Buffer<(Nat, V)>{

            let buffer = Buffer.Buffer<(Nat, V)>(0);

            for ((key, elem) in Map.entries(register.map)) {
                
                if (timeout_calculator.timeout_date(hot_info(elem)) <= time) {
                    buffer.add((key, elem));
                    Set.delete(register.locks, Map.nhash, key);
                };
            };

            buffer;
        };

    };
};