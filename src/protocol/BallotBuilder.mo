import Debug "mo:base/Debug";

import Types "Types";

module {

    type Time          = Int;
    type Account       = Types.Account;
    type BallotInfo<B> = Types.BallotInfo<B>;
    type DepositInfo   = Types.DepositInfo;
    type HotInfo       = Types.HotInfo;
    type RewardInfo    = Types.RewardInfo;
    type Ballot<B>     = Types.Ballot<B>;

    public class BallotBuilder<B>() {

        var _ballot  : ?BallotInfo<B> = null;
        var _deposit : ?DepositInfo   = null;
        var _hot     : ?HotInfo       = null;
        var _reward  : ?RewardInfo    = null;

        public func add_ballot(ballot : BallotInfo<B>){
            switch(_ballot){
                case(null) { _ballot := ?ballot; };
                case(_) { Debug.trap("Ballot Info has already been added"); };
            };
        };

        public func add_deposit(deposit: { tx_id: Nat; from: Account; subaccount: Blob; } ){
            switch(_deposit){
                case(null) { _deposit := ?{ deposit and { deposit_state = #LOCKED { until = 0; } } } }; // @todo: remove deposit state from here
                case(_) { Debug.trap("Deposit Info has already been added"); };
            };
        };

        public func add_hot(hot : HotInfo){
            switch(_hot){
                case(null) { _hot := ?hot; };
                case(_) { Debug.trap("Hot Info has already been added")};
            };
        };

        public func add_reward(reward : RewardInfo){
            switch(_reward){
                case(null) { _reward := ?reward; };
                case(_) { Debug.trap("Reward Info has already been added"); };
            };
        };

        public func build() : Ballot<B> {
            switch(_ballot, _deposit, _hot, _reward){
                case(?ballot, ?deposit, ?hot, ?reward) {
                    { ballot and deposit and hot and reward };
                };
                case(_){
                    Debug.trap("BallotBuilder: Missing required fields");
                };
            };
        };
        
    };

};