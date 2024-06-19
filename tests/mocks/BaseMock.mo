import Mocks "Mocks";

import Deque "mo:base/Deque";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

import Map "mo:map/Map";

module {

    type IMock<R> = Mocks.IMock<R>;

    public class BaseMock<R, M>({
        to_text: M -> Text;
        from_return: R -> M;
        method_hash: Map.HashUtils<M>;
    }) : IMock<R> {

        let expected_calls = Map.new<M, Deque.Deque<R>>();

        public func expect_call(args: R) {
            let method = from_return(args);
            let deque = Option.get(Map.get(expected_calls, method_hash, method), Deque.empty<R>());
            Map.set(expected_calls, method_hash, method, Deque.pushBack(deque, args));
        };

        public func pop_expected_call(method: M) : R {
            switch(Map.get(expected_calls, method_hash, method)){
                case(?deque) {
                    switch(Deque.popFront(deque)) {
                        case(?(head, tail)) {
                            if (Deque.isEmpty(tail)){
                                Map.delete(expected_calls, method_hash, method);
                            } else {
                                Map.set(expected_calls, method_hash, method, tail);
                            };
                            return head;
                        };
                        case(_) {};
                    };
                };
                case(_) {};
            };
            Debug.trap("Unexpected call to " # to_text(method));
        };

        public func teardown() {
            if (not Map.empty(expected_calls)){
                Debug.trap("Expected calls not made!");
            };
        };
    };
    
};