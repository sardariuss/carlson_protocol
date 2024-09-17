import HotMap            "HotMap";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Buffer            "mo:base/Buffer";
import Result            "mo:base/Result";

module {
    
    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    public type Lock = { timestamp: Time; duration_ns: Nat; };

    public type ILockInfoBuilder<T> = HotMap.IHotElemBuilder<T>;

    public type LockRegister<V> = {
        var index: Nat;
        map: Map.Map<Nat, V>;
        locks: Set.Set<Nat>;
    };
    
    public class LockScheduler<V>({
        hot_map: HotMap.HotMap<Nat, V>;
        lock_info: V -> Lock;
    }){

        public func preview_lock({
            register: LockRegister<V>;
            builder: ILockInfoBuilder<V>;
            amount: Nat;
            timestamp: Time;
        }) : V {
            hot_map.set_hot({ map = register.map; builder; args = { amount; timestamp; } });
        };

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

                if (Set.has(register.locks, Map.nhash, key)) {

                    let { timestamp; duration_ns; } = lock_info(elem);
                    
                    if (time - timestamp > duration_ns) {
                        buffer.add((key, elem));
                        Set.delete(register.locks, Map.nhash, key);
                    };
                };
            };

            buffer;
        };

    };
};