import Types            "../Types";

import HotMap           "../locks/HotMap";
import RewardScheduler  "../locks/RewardScheduler";

module {

    type Ballot<B> = Types.Ballot<B>;
    type RefundState = Types.RefundState;

    type HotElem = HotMap.HotElem;
    type RewardInfo = RewardScheduler.RewardInfo;

    type Time = Int;

    public func update_hot_info<B>(yes_no_ballot: Ballot<B>, elem: HotElem): Ballot<B> {
        { yes_no_ballot with elem; };
    };

    public func tag_refunded<B>(yes_no_ballot: Ballot<B>, state: RefundState): Ballot<B> {
        { yes_no_ballot with deposit_state = #REFUNDED(state); };
    };

    public func to_reward_info<B>(yes_no_ballot: Ballot<B>): RewardInfo {
        { account = yes_no_ballot.reward_account; state = yes_no_ballot.reward_state; };
    };

    public func update_reward_info<B>(yes_no_ballot: Ballot<B>, reward_info: RewardInfo): Ballot<B> {
        { yes_no_ballot with reward_state = reward_info.state; };
    };

};