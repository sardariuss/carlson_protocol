import Option "mo:base/Option";
import Debug "mo:base/Debug";

import Map "mo:map/Map";

module {

    type OnlyA = {a: Nat};
    type OnlyB = {b: Nat};
    type Both = {a: Nat; b: Nat};

    public type WMap<K, V> = {
        get: K -> ?V;
//        add: (K, V) -> ?V;
//        set: (K, V) -> ();
        replace: (K, V -> V) -> ?V;
    };

    public func partial_map<K, Partial, Complete>({
        map: Map.Map<K, Complete>;
        hash: Map.HashUtils<K>;
        from_complete: (Complete) -> (Partial);
        to_complete: (Partial) -> (Complete);
        update: (Complete, Partial) -> (Complete);
    }) : WMap<K, Partial> {

        return {
            get = func(key: K) : ?Partial {
                switch(Map.get(map, hash, key)){
                    case(null){ null; };
                    case(?complete) { ?from_complete(complete); };
                };
            };

//            add = func(key: K, value: Partial): ?Partial {
//                switch(Map.add<K, Complete>(map, hash, key, to_complete(value))){
//                    case(null){ null; };
//                    case(?complete) { ?from_complete(complete); };
//                };
//            };
//
//            set = func(key: K, value: Partial) {
//                let updated = switch(Map.get(map, hash, key)){
//                    case(null){ to_complete(value); };
//                    case(?complete) { update(complete, value); };
//                };
//
//                Map.set(map, hash, key, updated);
//            };

            replace = func(key: K, f: (Partial) -> (Partial)) : ?Partial {
                let complete = switch(Map.get(map, hash, key)){
                    case(null){ return null; };
                    case(?complete) { complete; };
                };

                let to_complete_partial = f(from_complete(complete));
                Map.set(map, hash, key, update(complete, to_complete_partial));
                ?to_complete_partial;
            };
        };

    };

    

    public func show_a(map: WMap<Nat, OnlyA>, key: Nat) {
        let val = switch(map.get(key)){
            case(null){ Debug.trap("No value found"); };
            case(?{a}) { a; };
        };

        Debug.print("a = " # debug_show(val));
    };

    public func show_b(map: WMap<Nat, OnlyB>, key: Nat) {
        let val = switch(map.get(key)){
            case(null){ Debug.trap("No value found"); };
            case(?{b}) { b; };
        };

        Debug.print("b = " # debug_show(val));
    };

    public func show_both(map: Map.Map<Nat, Both>, key: Nat) {
        let map_a = partial_map<Nat, OnlyA, Both>({
            map;
            hash = Map.nhash;
            from_complete = func(both: Both) : OnlyA { {a = both.a}; };
            update = func(both: Both, only_a: OnlyA) : Both { {both with a = only_a.a;}; };
            to_complete = func(only_a: OnlyA) : Both { {a = only_a.a; b = 0;}; };
        });

        let map_b = partial_map<Nat, OnlyB, Both>({
            map;
            hash = Map.nhash;
            from_complete = func(both: Both) : OnlyB { {b = both.b}; };
            update = func(both: Both, only_b: OnlyB) : Both { {both with b = only_b.b;}; };
            to_complete = func(only_b: OnlyB) : Both { {a = 0; b = only_b.b;}; };
        });

        show_a(map_a, key);
        show_b(map_b, key);
        
    };
}