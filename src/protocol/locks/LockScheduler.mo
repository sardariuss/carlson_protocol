import Types             "../Types";

import HotMap            "HotMap";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Buffer            "mo:base/Buffer";
import Result            "mo:base/Result";

module {
    
    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    public type Lock = { timestamp: Time; duration_ns: Nat; };
    public type UUID = Types.UUID;

    public type ILockInfoBuilder<T> = HotMap.IHotElemBuilder<T>;

    public type ReleaseAttempt<V> = Types.ReleaseAttempt<V>;

    public type LockRegister<V> = {
        map: Map.Map<UUID, V>;
        locks: Set.Set<UUID>;
    };
    
    public class LockScheduler<V>({
        hot_map: HotMap.HotMap<UUID, V>;
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
            key: UUID;
            amount: Nat;
            timestamp: Time;
        }) : Result<V, Text> {         
            
            let result = hot_map.add_new({ map = register.map; key; builder; args = { amount; timestamp; } });

            switch(result){
                case(#err(err)){ #err(err); };
                case(#ok(elem)){
                    Set.add(register.locks, Map.thash, key);
                    #ok(elem);
                };
            };
        };

        public func attempt_release({
            register: LockRegister<V>;
            time: Time;
        }) : Buffer.Buffer<(UUID, ReleaseAttempt<V>)>{

            let buffer = Buffer.Buffer<(UUID, ReleaseAttempt<V>)>(0);

            for ((key, elem) in Map.entries(register.map)) {
                
                // Check if the element is still locked.
                if (Set.has(register.locks, Map.thash, key)) {

                    let { timestamp; duration_ns; } = lock_info(elem);
                    var release_time : ?Time = null;
                    let unlock_date = timestamp + duration_ns;

                    // If the lock duration has passed, remove the lock.
                    if (unlock_date <= time) {
                        Set.delete(register.locks, Map.thash, key);
                        release_time := ?unlock_date;
                    };

                    // Add current element and release status.
                    buffer.add((key, { elem; release_time; update_elem = func(v: V) { Map.set(register.map, Map.thash, key, v); } }));
                };
            };

            buffer;
        };

    };
};