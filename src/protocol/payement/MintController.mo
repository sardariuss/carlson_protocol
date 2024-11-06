import PayementFacade "PayementFacade";
import Types          "../Types";
import MapUtils       "../utils/Map";

import Map            "mo:map/Map";
import Set            "mo:map/Set";

import Option         "mo:base/Option";

module {

    type Time = Int;
    type Account = Types.Account;
    type RewardState = Types.RewardState;
    type VoteRegister = Types.VoteRegister;
    type DatedAggregate<A> = Types.DatedAggregate<A>;
    type VoteId = Types.VoteId;
    type BallotId = Types.BallotId;
    
    public type RewardInfo = {
        account: Account;
        state: RewardState;
    };

    type ComputeConssent<A, B> = ({aggregate: A; choice: B;}) -> Float;

    public func compute_weighted_amount<A, B>({
        time: Time;
        released: ?Time;
        ballot: Types.Ballot<B>;
        aggregate_history: [DatedAggregate<A>];
        compute_consent: ComputeConssent<A, B>;
    }): Float {
        return 0.0; // @todo
    };

    public func compute_reward({
        total_weights: Float;
        weight: Float;
    }) : Nat {
        return 100_000; // @todo
    };
}