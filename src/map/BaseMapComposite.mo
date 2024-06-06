import IMap "IMap";

import Map  "mo:map/Map";

module {

    type IMapComposite<K, V, S> = IMap.IMapComposite<K, V, S>;
    type Map<K, V> = Map.Map<K, V>;
    type HashUtils<K> = Map.HashUtils<K>;
    type Iter<S> = { next: () -> ?S; };

    public class BaseMapComposite<K, V, S>(map: Map<K, V>, hash: HashUtils<K>, from_slice: S -> V) : IMapComposite<K, V, S> {

        public func set_from_slice(key: K, slice: S) : V {
            let value = from_slice(slice);
            set(key, value);
            value;
        };

        public func get(key: K): ?V {
            Map.get(map, hash, key);
        };
            
        public func has(key: K): Bool {
            Map.has(map, hash, key);
        };

        public func set(key: K, value: V) {
            Map.set(map, hash, key, value);
        };
            
        public func remove(key: K): ?V {
            Map.remove(map, hash, key);
        };
            
        public func delete(key: K) {
            Map.delete(map, hash, key);
        };

        public func peek() : ?(K, V) {
            Map.peek(map);
        };
            
        public func keys(): Iter<K> {
            Map.keys(map);
        };
            
        public func vals(): Iter<V> {
            Map.vals(map);
        };
            
        public func entries(): Iter<(K, V)> {
            Map.entries(map);
        };
            
        public func clear() {
            Map.clear(map);
        };
            
        public func size(): Nat {
            Map.size(map);
        };

    };

};