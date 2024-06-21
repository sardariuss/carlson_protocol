import MockTypes "MockTypes";

import Test "mo:test";

import Array "mo:base/Array";

module {
    
    public func test(name: Text, mocks: [MockTypes.ITearDownable], fn: () -> ()){
        Test.test(name, func() {
            fn(); 
            for (mock in Array.vals(mocks)) {
                mock.teardown();
            };
        });
    };
    
};