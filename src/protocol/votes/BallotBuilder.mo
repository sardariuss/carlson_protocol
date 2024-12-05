import Types "../Types";
import DurationCalculator "../duration/DurationCalculator";
import Timeline "../utils/Timeline";

import Debug "mo:base/Debug";

module {

    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type Time               = Int;
    type Account            = Types.Account;
    type BallotInfo<B>      = Types.BallotInfo<B>;
    type DepositInfo        = Types.DepositInfo;
    type HotInfo            = Types.HotInfo;
    type DurationInfo       = Types.DurationInfo;
    type Ballot<B>          = Types.Ballot<B>;

    public class BallotBuilder<B>({duration_calculator: IDurationCalculator}) {

        var _ballot   : ?BallotInfo<B> = null;
        var _deposit  : ?DepositInfo   = null;
        var _hot      : ?HotInfo       = null;
        var _duration : ?DurationInfo  = null;

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

        public func add_hot(hot : HotInfo, timestamp : Time){
            switch(_hot, _duration){
                case(null, null) {
                    _hot := ?hot;
                    let duration = duration_calculator.compute_duration_ns(hot.hotness);
                    _duration := ?{
                        duration_ns = Timeline.initialize(timestamp, duration);
                        var release_date = timestamp + duration;
                    }; 
                };
                case(_) { Debug.trap("Hot Info has already been added")};
            };
        };

        public func build() : Ballot<B> {
            switch(_ballot, _deposit, _hot, _duration){
                case(?ballot, ?deposit, ?hot, ?duration) {
                    { 
                        ballot_id = ballot.ballot_id;
                        vote_id = ballot.vote_id;
                        timestamp = ballot.timestamp;
                        choice = ballot.choice;
                        amount = ballot.amount;
                        dissent = ballot.dissent;
                        consent = ballot.consent;
                        ck_btc = ballot.ck_btc;
                        presence = ballot.presence;
                        resonance = ballot.resonance;
                        tx_id = deposit.tx_id;
                        from = deposit.from;
                        var hotness = hot.hotness;
                        decay = hot.decay;
                        duration_ns = duration.duration_ns;
                        var release_date = duration.release_date;
                    };
                };
                case(_){
                    Debug.trap("BallotBuilder: Missing required fields");
                };
            };
        };
        
    };

};