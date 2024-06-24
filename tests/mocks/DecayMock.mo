import MockTypes "MockTypes";
import BaseMock "BaseMock";
import Interfaces "../../src/protocol/Interfaces";

import Debug "mo:base/Debug";

module {

    type Time = Int;

    public type Method = {
        #compute_decay;
    };

    public type Return = {
        #compute_decay: {
            #returns: Float;
        };
    };

    public class DecayMock() : Interfaces.IDecayModel and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#compute_decay) { "compute_decay"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#compute_decay(_)) { #compute_decay; };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#compute_decay) { 1; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#compute_decay, #compute_decay) { true };
                    };
                }
            )
        });

        public func compute_decay(_: Time) : Float {
            let arg = base.pop_expected_call(#compute_decay);
            switch(arg){
                case(#compute_decay(#returns(value))) {
                    return value;
                };
            };
            Debug.trap("Unexpected argument for compute_decay!");
        };

        public func expect_call(arg: Return) {
            base.expect_call(arg);
        };

        public func expect_calls(args: [Return]) {
            base.expect_calls(args);
        };

        public func teardown() {
            base.teardown();
        };

    };
    
};