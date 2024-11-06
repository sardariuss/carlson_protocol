import Types            "../Types";

import HotMap           "../locks/HotMap";
import RewardDispenser  "../payement/RewardDispenser";

module {

    type Ballot<B> = Types.Ballot<B>;
    type RefundState = Types.RefundState;

    type HotElem = HotMap.HotElem;
    type RewardInfo = RewardDispenser.RewardInfo;

    type Time = Int;

    public func update_hot_info<B>(yes_no_ballot: Ballot<B>, elem: HotElem): Ballot<B> {
        { yes_no_ballot with elem; };
    };

    public func tag_refunded<B>(yes_no_ballot: Ballot<B>, state: RefundState): Ballot<B> {
        { yes_no_ballot with deposit_state = #REFUNDED(state); };
    };

};