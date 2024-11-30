import Types "../Types";

import Map "mo:map/Map";
import Set "mo:map/Set";

import Prim "mo:prim";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Debug "mo:base/Debug";

module {

    type Map<K, V>        = Map.Map<K, V>;
    type Set<K>           = Set.Set<K>;
    type HashUtils<K>     = Map.HashUtils<K>;
    type Account          = Types.Account;

    type Map2D<K1, K2, V> = Map<K1, Map<K2, V>>;

    public let nnhash: HashUtils<(Nat, Nat)> = (
        func(key) = (Map.nhash.0((key.0)) ^ (Map.nhash.0((key.1)) << 1)) & 0x3fffffff,
        func(a, b) = a.0 == b.0 and a.1 == b.1,
    );

    public let tnhash: HashUtils<(Text, Nat)> = (
        func(key) = (Map.thash.0((key.0)) ^ (Map.nhash.0((key.1)) << 1)) & 0x3fffffff,
        func(a, b) = a.0 == b.0 and a.1 == b.1,
    );

    public let acchash: HashUtils<Account> = (
        func(key) =
            switch (key.subaccount) {
                case (null) { Prim.hashBlob(Prim.blobOfPrincipal(key.owner)) };
                case (?blob) { ((Prim.hashBlob(Prim.blobOfPrincipal(key.owner)) << 1) ^ Prim.hashBlob(blob)) & 0x3fffffff };
            },
        func(a, b) = a.owner == b.owner and a.subaccount == b.subaccount,
    );

    public func getOrTrap<K, V>(map: Map<K, V>, hash: HashUtils<K>, key: K) : V {
        switch(Map.get(map, hash, key)){
            case(null) { Debug.trap("Key not found"); };
            case(?v) { v; };
        };
    };

    public func has2D<K1, K2, V>(map2D: Map2D<K1, K2, V>, k1_hash: HashUtils<K1>, k1: K1, k2_hash: HashUtils<K2>, k2: K2) : Bool {
        switch(Map.get(map2D, k1_hash, k1)){
            case(null) { false };
            case(?map1D) { Map.has(map1D, k2_hash, k2) };
        };
    };

    public func put2D<K1, K2, V>(map2D: Map2D<K1, K2, V>, k1_hash: HashUtils<K1>, k1: K1, k2_hash: HashUtils<K2>, k2: K2, v: V) : ?V {
        let map1D = Option.get(Map.get(map2D, k1_hash, k1), Map.new<K2, V>());
        let old_v = Map.put(map1D, k2_hash, k2, v);
        ignore Map.put(map2D, k1_hash, k1, map1D); // @todo: might be required only if the inner map is new
        old_v;
    };

    public func get2D<K1, K2, V>(map2D: Map2D<K1, K2, V>, k1_hash: HashUtils<K1>, k1: K1, k2_hash: HashUtils<K2>, k2: K2) : ?V {
        Option.chain(Map.get(map2D, k1_hash, k1), func(map1D: Map<K2, V>) : ?V {
            Map.get(map1D, k2_hash, k2);
        });
    };

    // @todo: optimization: remove emptied sub trie if any
    public func remove2D<K1, K2, V>(map2D: Map2D<K1, K2, V>, k1_hash: HashUtils<K1>, k1: K1, k2_hash: HashUtils<K2>, k2: K2) : ?V {
        Option.chain(Map.get(map2D, k1_hash, k1), func(map1D: Map<K2, V>) : ?V {
            let old_v = Map.remove(map1D, k2_hash, k2);
            ignore Map.put(map2D, k1_hash, k1, map1D); // @todo: might not be required
            old_v;
        });
    };

    public func entries2D<K1, K2, V>(map2D: Map2D<K1, K2, V>) : Iter.Iter<(K1, Iter.Iter<(K2, V)>)> {
        Iter.map<(K1, Map<K2, V>), (K1, Iter.Iter<(K2, V)>)>(Map.entries(map2D), func((k1, map1D): (K1, Map<K2, V>)) : (K1, Iter.Iter<(K2, V)>) {
            (k1, Map.entries(map1D));
        });
    };

    public func putInnerSet<K1, K2>(map: Map<K1, Set<K2>>, k1_hash: HashUtils<K1>, k1: K1, k2_hash: HashUtils<K2>, k2: K2) {
        let set : Set<K2> = Option.get(Map.get(map, k1_hash, k1), Set.new<K2>());
        Set.add<K2>(set, k2_hash, k2);
        Map.set(map, k1_hash, k1, set); // @todo: might be required only if the inner set is new
    };

};