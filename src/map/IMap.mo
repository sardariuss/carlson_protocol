
module {

    type Iter<T> = { next: () -> ?T; };
    
    public type IMap<K, V> = {
        get: (key: K) -> ?V;
        has: (key: K) -> Bool;
        set: (key: K, value: V) -> ();
        remove: (key: K) -> ?V;
        delete: (key: K) -> ();
        peek: () -> ?(K, V);
        keys: () -> Iter<K>;
        vals: () -> Iter<V>;
        entries: () -> Iter<(K, V)>;
        clear: () -> ();
        size: () -> Nat;
    };

    public type IMapCompositer<K, V, S> = {
        set_from_slice: (key: K, slice: S) -> V;
    };

    public type IMapComposite<K, V, S> = IMap<K, V> and IMapCompositer<K, V, S>;

};