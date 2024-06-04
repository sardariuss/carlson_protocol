import Types "../Types";
import Locker "Locker";
import HotMap "../map/HotMap";
import BaseMap "../map/BaseMap";
import IMap "../map/IMap";
import Decay "../Decay";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

module {

    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;
    type LockState = Locker.LockState;
    type DecayModel = Decay.DecayModel;

    type Time = Int;

    public func build<V, T>({
        get_lock: V -> LockState;
        update_lock: (V, LockState) -> V;
        unlock_condition: (V, Time) -> Bool;
        decay_model: DecayModel;
        converters: {
            get_inputs: HotMap.GetInputs<T>;
            get_outputs: HotMap.GetOutputs<V>;
            to_hot: HotMap.ToHot<T, V>;
            update_hotness: HotMap.UpdateHot<V>;
        };
    }) : HotLocker<V, T> {
        let locker = Locker.Locker<V>({
            get_lock;
            update_lock;
            unlock_condition;
        });
        let hotter = HotMap.HotMap<Nat, V, T>({
            decay_model;
            converters;
        });
        HotLocker<V, T>({ locker; hotter; });
    };

    public class HotLocker<V, T>({
        locker: Locker.Locker<V>;
        hotter: HotMap.HotMap<Nat, V, T>;
    }){

        public func add_composite_lock({
            map: Map<Nat, V>;
            new: Locker.LockState -> T;
            key: Nat;
            time: Time;
        }) : (Nat, V) {
            let map_composite = hotter.get_map_composite({ map; hash = Map.nhash; });
            locker.add_lock<T>({ map_composite; key; new; time; })
        };

        public func try_unlock({
            map: Map<Nat, V>;
            time: Time;
        }) : Buffer.Buffer<(Nat, V)>{
          locker.try_unlock({ map = BaseMap.BaseMap<Nat, V>(map, Map.nhash); time; });  
        };

    };
}