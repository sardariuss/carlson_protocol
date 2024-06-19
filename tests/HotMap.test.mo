import Interfaces "../src/Interfaces";
import HotMap   "../src/locks/HotMap";
import Duration "../src/Duration";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Deque "mo:base/Deque";
import Debug "mo:base/Debug";

import { verify; Testify; } = "utils/Testify";
import Candy "mo:candy/types";

suite("HotMap", func(){

    type CallArgs = {
        method: Text;
        returns: Candy.Candy;
    };

    type IMock = {
        expect_call: (CallArgs) -> ();
        teardown: () -> ();
    };

    func with_mock(mock: IMock, test: IMock -> ()) {
        test(mock);
        mock.teardown();
    };

    class DecayMock() : Interfaces.IDecayModel and IMock {

        var expected_calls = Deque.empty<Float>();

        public func expect_call(args: CallArgs) {
            if (args.method == "compute_decay") {
                switch(args.returns) {
                    case(#Float(val)){
                        expected_calls := Deque.pushBack(expected_calls, val);
                    };
                    case(_){
                        Debug.trap("Unsupported return type: " # debug_show(args.returns));
                    };
                };
            } else {
                Debug.trap("Unsupported method: " # args.method);
            };
        };

        public func expect_compute_decay(value: Float) {
            expected_calls := Deque.pushBack(expected_calls, value);
        };

        public func compute_decay(_: Time.Time) : Float {
            switch(Deque.popFront(expected_calls)) {
                case(null) {
                    Debug.trap("Unexpected call to compute_decay!");
                };
                case(?(poped, deque)) {
                    expected_calls := deque;
                    poped;
                };
            };
        };

        public func teardown() {
            if (not Deque.isEmpty(expected_calls)){
                Debug.trap("Expected calls to compute_decay not made!");
            };
        };

    };

    test("@todo", func(){

        with_mock(DecayMock(), func(mock: IMock) {
            mock.expect_call({ method = "compute_decay"; returns = #Float(1.0) });
        });
    });
    
})