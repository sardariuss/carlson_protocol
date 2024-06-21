import { test } "mocks";
import DecayMock "mocks/DecayMock";
import { verify; Testify; } = "utils/Testify";
import HotMap "../src/locks/HotMap";

import Map "mo:map/Map";
import { suite; } "mo:test";

import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";

suite("HotMap", func(){

    type Result<Ok> = Result.Result<Ok, Text>;

    type IBuilder<A, E> = {
        add_hot: (A) -> ();
        build() : E;
    };

    class CreateBuilder<P, A, E>({partial: P; to_elem: (P, A) -> E}) : IBuilder<A, E> {
            
        var _added: ?A = null;

        public func add_hot(to_add: A){ // @todo: find a way to generalize this with BallotBuilder
            switch(_added){
                case(null) { _added := ?to_add; };
                case(_) { Debug.trap("Element has already been added")};
            };
        };

        public func build() : E {
            switch(_added){
                case(?added) { to_elem((partial, added)); };
                case(_){ Debug.trap("Element misses the add"); };
            };
        };
    };

    type Time = Int;

    type HotInput = HotMap.HotInput;
    type HotOutput = HotMap.HotOutput;
    type HotElem = HotMap.HotElem;

    let decay_model = DecayMock.DecayMock();

    let hot_map = HotMap.HotMap<Nat, HotElem>({
        decay_model;
        get_elem = func(e: HotElem) : HotElem { e; };
        update_elem = func(before: HotElem, update: HotElem) : HotElem { update; };
        key_hash = Map.nhash;
    });

    func add_new({map: Map.Map<Nat, HotElem>; key: Nat; args: HotInput}) : Result<HotElem> {
        let builder = CreateBuilder({ 
            partial = args; 
            to_elem = func(partial: HotInput, added: HotOutput) : HotElem { { partial and added }; };
        });
        hot_map.add_new({ map; key; builder; args; });
    };

    test("Unique keys", [decay_model], func() {
        let map = Map.new<Nat, HotElem>();
        let args = { amount = 100; timestamp = 1; };
        decay_model.expect_calls(Array.tabulate(2, func(_: Nat) : DecayMock.Return { #compute_decay(#returns(1.0)); } ));
        verify<Bool>(Result.isOk(add_new({ map; key = 1; args; })), true , Testify.bool.equal);
        verify<Bool>(Result.isOk(add_new({ map; key = 2; args; })), true , Testify.bool.equal);
        verify<Bool>(Result.isOk(add_new({ map; key = 2; args; })), false, Testify.bool.equal);
    });

    test("Timestamp ordering", [decay_model], func() {
        let map = Map.new<Nat, HotElem>();
        let amount = 100;
        decay_model.expect_calls(Array.tabulate(3, func(_: Nat) : DecayMock.Return { #compute_decay(#returns(1.0)); } ));
        verify<Bool>(Result.isOk(add_new({ map; key = 1; args = { amount; timestamp = 10;   }; })), true , Testify.bool.equal);
        verify<Bool>(Result.isOk(add_new({ map; key = 2; args = { amount; timestamp = 100;  }; })), true , Testify.bool.equal);
        verify<Bool>(Result.isOk(add_new({ map; key = 3; args = { amount; timestamp = 1000; }; })), true , Testify.bool.equal);
        verify<Bool>(Result.isOk(add_new({ map; key = 3; args = { amount; timestamp = 999;  }; })), false, Testify.bool.equal);
    });
    
});