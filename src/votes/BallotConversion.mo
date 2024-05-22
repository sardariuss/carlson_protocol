import Types "../Types";

import LockScheduler "../locks/LockScheduler";
import DepositScheduler "../locks/DepositScheduler";
import YieldScheduler "../locks/YieldScheduler";

module {

    type Ballot<B> = Types.Ballot<B>;

    type LockInfo = LockScheduler.LockInfo;
    type DepositInfo = DepositScheduler.DepositInfo;
    type YieldInfo = YieldScheduler.YieldInfo;

    type Time = Int;

    public func to_lock_info<B>(yes_no_ballot: Ballot<B>): LockInfo {
        {
            yes_no_ballot with
            state = switch(yes_no_ballot.deposit_state) {
                case(#LOCKED{until}) { #LOCKED{until} };
                case(#UNLOCKED{since}) { #UNLOCKED{since} };
            };
        };
    };

    public func update_lock_info<B>(yes_no_ballot: Ballot<B>, lock_info: LockInfo): Ballot<B> {
        { 
            yes_no_ballot with
            hotness = lock_info.hotness;
            decay = lock_info.decay;
            state = switch(lock_info.state) {
                case(#LOCKED{until}) { #LOCKED{until} };
                case(#UNLOCKED{since}) { #UNLOCKED{since; transfer = #PENDING;} };
            };
        };
    };

    public func to_deposit_info<B>(yes_no_ballot: Ballot<B>): DepositInfo {
        {
            yes_no_ballot with
            state = yes_no_ballot.deposit_state;
            account = yes_no_ballot.from;
        };
    };

    public func update_deposit_info<B>(yes_no_ballot: Ballot<B>, deposit_info: DepositInfo): Ballot<B> {
        {
            yes_no_ballot with
            state = deposit_info.state;
        };
    };

    public func to_yield_info<B>(yes_no_ballot: Ballot<B>): YieldInfo {
        {
            account = yes_no_ballot.reward_account;
            state = yes_no_ballot.reward_state;
        };
    };

    public func update_yield_info<B>(yes_no_ballot: Ballot<B>, yield_info: YieldInfo): Ballot<B> {
        {
            yes_no_ballot with
            reward_state = yield_info.state;
        };
    };

};