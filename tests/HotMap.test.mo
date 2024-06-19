import Mocks "mocks/Mocks";
import DecayMock "mocks/DecayMock";

import { test; suite; } "mo:test";

import { verify; Testify; } = "utils/Testify";

suite("HotMap", func(){


    test("@todo", func(){

        Mocks.with_mock(DecayMock.DecayMock(), func(mock: Mocks.IMock<DecayMock.Return>) {
            mock.expect_call(#compute_decay(#returns(1.0)));
        });
    });
    
})