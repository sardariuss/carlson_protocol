import Types "../Types";
import DurationCalculator "../duration/DurationCalculator";

import Debug "mo:base/Debug";

module {

    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type Time               = Int;
    type Account            = Types.Account;
    type BallotInfo<B>      = Types.BallotInfo<B>;
    type DepositInfo        = Types.DepositInfo;
    type HotInfo            = Types.HotInfo;
    type RewardInfo         = Types.RewardInfo;
    type DurationInfo       = Types.DurationInfo;
    type Ballot<B>          = Types.Ballot<B>;

    public class BallotBuilder<B>({duration_calculator: IDurationCalculator}) {

        var _ballot   : ?BallotInfo<B> = null;
        var _deposit  : ?DepositInfo   = null;
        var _hot      : ?HotInfo       = null;
        var _duration : ?DurationInfo  = null;
        var _reward   : ?RewardInfo    = null;

        public func add_ballot(ballot : BallotInfo<B>){
            switch(_ballot){
                case(null) { _ballot := ?ballot; };
                case(_) { Debug.trap("Ballot Info has already been added"); };
            };
        };

        public func add_deposit(deposit: DepositInfo){
            switch(_deposit){
                case(null) { _deposit := ?deposit };
                case(_) { Debug.trap("Deposit Info has already been added"); };
            };
        };

        public func add_hot(hot : HotInfo){
            switch(_hot, _duration){
                case(null, null) { 
                    _hot := ?hot; 
                    _duration := ?{ duration_ns = duration_calculator.compute_duration_ns(hot); };
                };
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
            switch(_ballot, _deposit, _hot, _reward, _duration){
                case(?ballot, ?deposit, ?hot, ?reward, ?duration) {
                    { ballot and deposit and hot and reward and duration };
                };
                case(_){
                    Debug.trap("BallotBuilder: Missing required fields");
                };
            };
        };
        
    };

};