module {
    
    public type ITearDownable = {
        teardown: () -> ();
    };

    public type IMock<R> = ITearDownable and {
        expect_call: R -> ();
        expect_calls: [R] -> ();
    };

};