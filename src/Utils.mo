import Buffer "mo:base/Buffer";
import Result "mo:base/Result";

module {

    type Buffer<T> = Buffer.Buffer<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    
    type AsyncCallBack<Ok, Err> = () -> async* Result<Ok, Err>;

    public func run_in_parallel(callbacks: Buffer<AsyncCallBack>) : async () {
        
        let runs = Buffer.Buffer<async()>(callbacks.size());

        for (callback in callbacks.vals()){
            runs.add(callback());
        };

        for (run in runs.vals()){
            await run;
        };
    };
}