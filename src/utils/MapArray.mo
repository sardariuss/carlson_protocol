import Map "mo:map/Map";

import Option "mo:base/Option";
import Buffer "mo:base/Buffer";

module {

    type MapArray<K, V> = Map.Map<K, [V]>;

    public func add<K, V>(map: MapArray<K, V>, hash: Map.HashUtils<K>, key: K, value: V) {
        let array = Option.get<[V]>(Map.get(map, hash, key), []);
        let buffer = Buffer.fromArray<V>(array);
        buffer.add(value);
        Map.set(map, hash, key, Buffer.toArray(buffer));
    };

};