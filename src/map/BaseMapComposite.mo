import IMap "IMap";

import Map  "mo:map/Map";

module {

    type IMapComposite<K, V, T> = IMap.IMapComposite<K, V, T>;
    type Map<K, V> = Map.Map<K, V>;
    type HashUtils<K> = Map.HashUtils<K>;
    type Iter<T> = { next: () -> ?T; };

    public class BaseMapComposite<K, V, T>(map: Map<K, V>, hash: HashUtils<K>, new: T -> V) : IMapComposite<K, V, T> {

        public func composite_set(key: K, elem: T) : V {
            let value = new(elem);
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