import Map "mo:map/Map";

import Iter "mo:base/Iter";

module {

    type Map<K, V> = Map.Map<K, V>;
    type HashUtils<K> = Map.HashUtils<K>;

    public type IWMap<K, V> = {
        get: (key: K) -> ?V;
        has: (key: K) -> Bool;
        put: (key: K, value: V) -> ?V;
        set: (key: K, value: V) -> ();
        remove: (key: K) -> ?V;
        delete: (key: K) -> ();
        filter: (fn: (key: K, value: V) -> Bool) -> Map<K, V>;
        peek: () -> ?(K, V);
        keys: () -> Iter.Iter<K>;
        vals: () -> Iter.Iter<V>;
        entries: () -> Iter.Iter<(K, V)>;
        forEach: (fn: (key: K, value: V) -> ()) -> ();
        some: (fn: (key: K, value: V) -> Bool) -> Bool;
        every: (fn: (key: K, value: V) -> Bool) -> Bool;
        find: (fn: (key: K, value: V) -> Bool) -> ?(K, V);
        findDesc: (fn: (key: K, value: V) -> Bool) -> ?(K, V);
        clear: () -> ();
        size: () -> Nat;
    };

    public func new<K, V>(hash: HashUtils<K>) : WMap<K, V> {
        WMap(Map.new<K, V>(), hash);
    };

    public class WMap<K, V>(map: Map<K, V>, hash: HashUtils<K>) : IWMap<K, V> {

        public func get(key: K): ?V {
            Map.get(map, hash, key);
        };
            
        public func has(key: K): Bool {
            Map.has(map, hash, key);
        };
            
        public func put(key: K, value: V): ?V {
            Map.put(map, hash, key, value);
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
            
        public func filter(fn: (key: K, value: V) -> Bool): Map<K, V> {
            Map.filter(map, hash, fn);
        };

        public func peek() : ?(K, V) {
            Map.peek(map);
        };
            
        public func keys(): Iter.Iter<K> {
            Map.keys(map);
        };
            
        public func vals(): Iter.Iter<V> {
            Map.vals(map);
        };
            
        public func entries(): Iter.Iter<(K, V)> {
            Map.entries(map);
        };
            
        public func forEach(fn: (key: K, value: V) -> ()) {
            Map.forEach(map, fn);
        };
            
        public func some(fn: (key: K, value: V) -> Bool): Bool {
            Map.some(map, fn);
        };
            
        public func every(fn: (key: K, value: V) -> Bool): Bool {
            Map.every(map, fn);
        };
            
        public func find(fn: (key: K, value: V) -> Bool): ?(K, V) {
            Map.find(map, fn);
        };
            
        public func findDesc(fn: (key: K, value: V) -> Bool): ?(K, V) {
            Map.findDesc(map, fn);
        };
            
        public func clear() {
            Map.clear(map);
        };
            
        public func size(): Nat {
            Map.size(map);
        };

    };

};