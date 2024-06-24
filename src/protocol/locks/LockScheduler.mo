import HotMap            "HotMap";
import TimeoutCalculator "../TimeoutCalculator";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Buffer            "mo:base/Buffer";
import Result            "mo:base/Result";

module {
    
    type Time = Int;
    type ITimeoutCalculator = TimeoutCalculator.ITimeoutCalculator;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type ILockInfoBuilder<T> = HotMap.IHotElemBuilder<T>;

    public type LockRegister<V> = {
        var index: Nat;
        map: Map.Map<Nat, V>;
        locks: Set.Set<Nat>;
    };
    
    public class LockScheduler<V>({
        hot_map: HotMap.HotMap<Nat, V>;
        timeout_calculator: ITimeoutCalculator;
        hot_info: V -> HotMap.HotElem;
    }){

        public func add_lock({
            register: LockRegister<V>;
            builder: ILockInfoBuilder<V>;
            amount: Nat;
            timestamp: Time;
        }) : Result<(Nat, V), Text> {

            let key = register.index;
            register.index := register.index + 1;
            
            let result = hot_map.add_new({ map = register.map; key; builder; args = { amount; timestamp; } });

            switch(result){
                case(#err(err)){ #err(err); };
                case(#ok(elem)){
                    Set.add(register.locks, Map.nhash, key);
                    #ok((key, elem));
                };
            };
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