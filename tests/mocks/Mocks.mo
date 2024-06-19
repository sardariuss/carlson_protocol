
module {

    public type IMock<R> = {
        expect_call: R -> ();
        teardown: () -> ();
    };

    public func with_mock<R>(mock: IMock<R>, test: IMock<R> -> ()) {
        test(mock);
        mock.teardown();
    };
    
};