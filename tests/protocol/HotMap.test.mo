import { test } "../mocks";
import DecayMock "../mocks/DecayMock";
import { verify; Testify; } = "../utils/Testify";
import HotMap "../../src/protocol/locks/HotMap";

import Map "mo:map/Map";
import { suite; } "mo:test";

import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";

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

    test("Hotness values", [], func() {
        
        test("Same amounts, same decays", [decay_model], func() {
            let hot_equal = Testify.result(Testify.hot_elem.equal, Testify.text.equal).equal;
            let map = Map.new<Nat, HotElem>();
            
            let args = { amount = 100; timestamp = 1; };
            decay_model.expect_calls(Array.tabulate(3, func(_: Nat) : DecayMock.Return { #compute_decay(#returns(1.0)); } ));
            
            verify(add_new({ map; key = 1; args; }), #ok({ args and { hotness = 100.0; decay = 1.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 100.0; decay = 1.0; } },
            ], Testify.array(Testify.hot_elem.equal).equal);

            verify(add_new({ map; key = 2; args; }), #ok({ args and { hotness = 200.0; decay = 1.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 200.0; decay = 1.0; } },
                { args and { hotness = 200.0; decay = 1.0; } },
            ], Testify.array(Testify.hot_elem.equal).equal);

            verify(add_new({ map; key = 3; args; }), #ok({ args and { hotness = 300.0; decay = 1.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 300.0; decay = 1.0; } },
                { args and { hotness = 300.0; decay = 1.0; } },
                { args and { hotness = 300.0; decay = 1.0; } },
            ], Testify.array(Testify.hot_elem.equal).equal);
        });

        test("Same amounts, different decays", [decay_model], func() {
            let hot_equal = Testify.result(Testify.hot_elem.equal, Testify.text.equal).equal;
            let map = Map.new<Nat, HotElem>();
            
            let args = { amount = 100; timestamp = 1; };

            decay_model.expect_call(#compute_decay(#returns(1.0)));
            verify(add_new({ map; key = 1; args; }), #ok({ args and { hotness = 100.0; decay = 1.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 100.0; decay = 1.0; } },
            ], Testify.array(Testify.hot_elem.equal).equal);

            decay_model.expect_call(#compute_decay(#returns(2.0)));
            verify(add_new({ map; key = 2; args; }), #ok({ args and { hotness = 150.0; decay = 2.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 150.0; decay = 1.0; } }, // previous + 100 * 1.0 / 2.0
                { args and { hotness = 150.0; decay = 2.0; } }, // amount   +      sum
            ], Testify.array(Testify.hot_elem.equal).equal);

            decay_model.expect_call(#compute_decay(#returns(4.0)));
            verify(add_new({ map; key = 3; args; }), #ok({ args and { hotness = 175.0; decay = 4.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 175.0; decay = 1.0; } }, // previous + 100 * 1.0 / 4.0 = previous + 25.0
                { args and { hotness = 200.0; decay = 2.0; } }, // previous + 100 * 2.0 / 4.0 = previous + 50.0
                { args and { hotness = 175.0; decay = 4.0; } }, // amount   +      sum        = amount   + 75.0
            ], Testify.array(Testify.hot_elem.equal).equal);

            decay_model.expect_call(#compute_decay(#returns(10.0)));
            verify(add_new({ map; key = 4; args; }), #ok({ args and { hotness = 170.0; decay = 10.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { args and { hotness = 185.0; decay =  1.0; } }, // previous + 100 * 1.0 / 10.0 = previous + 10.0
                { args and { hotness = 220.0; decay =  2.0; } }, // previous + 100 * 2.0 / 10.0 = previous + 20.0
                { args and { hotness = 215.0; decay =  4.0; } }, // previous + 100 * 4.0 / 10.0 = previous + 40.0
                { args and { hotness = 170.0; decay = 10.0; } }, // amount   +      sum         = amount   + 70.0
            ], Testify.array(Testify.hot_elem.equal).equal);
        });

        test("Different amounts, different decays", [decay_model], func() {
            let hot_equal = Testify.result(Testify.hot_elem.equal, Testify.text.equal).equal;
            let map = Map.new<Nat, HotElem>();

            var args = { amount = 100; timestamp = 1; };
            decay_model.expect_call(#compute_decay(#returns(1.0)));
            verify(add_new({ map; key = 1; args; }), #ok({ args and { hotness = 100.0; decay = 1.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { amount = 100; timestamp = 1; hotness = 100.0; decay = 1.0; },
            ], Testify.array(Testify.hot_elem.equal).equal);

            args := { amount = 200; timestamp = 1; };
            decay_model.expect_call(#compute_decay(#returns(2.0)));
            verify(add_new({ map; key = 2; args; }), #ok({ args and { hotness = 250.0; decay = 2.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { amount = 100; timestamp = 1; hotness = 200.0; decay = 1.0; }, // previous + 200 * 1.0 / 2.0 = previous + 100.0
                { amount = 200; timestamp = 1; hotness = 250.0; decay = 2.0; }, // amount   + 100 * 1.0 / 2.0 = amount   + 50.0
            ], Testify.array(Testify.hot_elem.equal).equal);

            args := { amount = 50; timestamp = 1; };
            decay_model.expect_call(#compute_decay(#returns(5.0)));
            verify(add_new({ map; key = 3; args; }), #ok({ args and { hotness = 150.0; decay = 5.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { amount = 100; timestamp = 1; hotness = 210.0; decay = 1.0; }, // previous + 50 * 1.0 / 5.0  = previous + 10.0
                { amount = 200; timestamp = 1; hotness = 270.0; decay = 2.0; }, // previous + 50 * 2.0 / 5.0  = previous + 20.0
                { amount = 50;  timestamp = 1; hotness = 150.0; decay = 5.0; }, // amount   + 100 * 1.0 / 5.0 
                                                                                //          + 200 * 2.0 / 5.0 = amount   + 20.0 + 80.0
            ], Testify.array(Testify.hot_elem.equal).equal);

            args := { amount = 500; timestamp = 1; };
            decay_model.expect_call(#compute_decay(#returns(10.0)));
            verify(add_new({ map; key = 4; args; }), #ok({ args and { hotness = 575.0; decay = 10.0; } }), hot_equal);
            verify(Iter.toArray(Map.vals(map)), [
                { amount = 100; timestamp = 1; hotness = 260.0; decay =  1.0; }, // previous + 500 * 1.0 / 10.0 = previous + 50.0
                { amount = 200; timestamp = 1; hotness = 370.0; decay =  2.0; }, // previous + 500 * 2.0 / 10.0 = previous + 100.0
                { amount = 50;  timestamp = 1; hotness = 400.0; decay =  5.0; }, // previous + 500 * 5.0 / 10.0 = previous + 250.0
                { amount = 500; timestamp = 1; hotness = 575.0; decay = 10.0; }, // amount   + 100 * 1.0 / 10.0 
                                                                                 //          + 200 * 2.0 / 10.0 
                                                                                 //          + 50  * 5.0 / 10.0 = amount   + 10.0 + 40.0 + 25.0
            ], Testify.array(Testify.hot_elem.equal).equal);
        });

    });
    
});