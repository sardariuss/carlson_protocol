# The Carlson Protocol

*My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong [...] If you pay enough attention you can rate your own performance, just as if you're betting on sports [...] To tell the truth is my main view and I plan to do that to the best of my ability.*
> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM_O80?si=bSkrQ0C2GeTJe7TV&t=118)

## A decision protocol for seeking the truth

The Carlson Protocol is a decentralized voting system where people vote using bitcoins. These bitcoins are transferred back to the user after a period of time that can vary according to specific rules. When reimbursed, users get rewarded with additional tokens that depend on how their past vote aligns with the current view.

✨ **The Carlson Protocol leverages how much people care**. If you don't care enough about a vote, you won't be willing to lock tokens for it.

⚔️ **The Carlson Protocol is a double-edged sword**. The more bitcoins you lock in a vote, the greater your voice, but the lesser the reward per coin and the longer the lock.

🗽 **The Carlson Protocol is stateless**. Votes never end, and results decay. Even the most one-sided votes will decay over time, offering the opportunity to reevaluate past consensus.

💪 **The Carlson Protocol rewards the bold**. Stand for your beliefs against the crowd. If the future proves you right, you will be rewarded.

## How does it work?

The Carlson protocol allows to participate on votes that really matters to you. To participate to a vote, pick your side ('Aye' or 'Nay') and choose an amount of satoshi to use for that vote: the greater the amount, the greater the power (1 satoshi = 1 vote). The satoshis will be transfered back to you after a period of time that can vary so that:
 - the greater the total of satoshis locked in a vote (including the ones from your ballot), the longer the satoshis from your ballot will be locked. But note that every satoshi locked is pondered by how much time has passed between that ballot and yours, so that the more time has passed, the least effect these satoshis have on your lock.
 - your ballot locking period will also be extended by the satoshis from every ballot that comes after you (also reduced by how much time has passed in-between).

 Once the satoshis are unlocked, the protocol rewards the voters with additional tokens that are minted with the configured (ICRC) token. The reward is based on the numbers of tokens you locked, the number of 'Aye' or 'Nay' satoshis at the time you voted, and the number of 'Aye' or 'Nay' satoshis at the time of the unlock, so that:
 - the further your vote was to the result of the vote at the time of the lock, the greater the reward
 - the closer your vote is to the result of the vote at the time of unlock, the greater the reward.
This incentivize user to vote "against the crowd", so that if they are right at the moment they vote but the crowd is wrong, if the tendency of the vote indeed changes over time, they will get rewarded more than the users who voted "with the crowd" and that now are wrong.

## Canister arguments

- `deposit_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the ballots (aims to be ckBTC)
- `reward_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the rewards
- `parameters.nominal_lock_duration`: the duration of the lock for 1 satoshi
- `parameters.ballot_half_life`: used to compute the effect of other ballots on a given ballot to update the lock date, so that the shorter (resp. the longer) the timespan between the date of that ballot and the others, the more (resp. the less) time is added to the ballot's lock. The same parameter is used to make the ballot decay

## 🚧 TODOs

### Backend
 - Do not allow an anonymous principal to open a vote
 - Temporarly multiply rewards by 10^8 until the minting logic is implemented

### Frontend

#### Postponed
 - Fix approve tokens, right now it only works once
    -> Will be fixed when bringing real wallet

#### Low priority
 - Add question mark + explanation for yield preview (volume * dissent_t_0 * consent_t_end)
 - Show bar of satoshis locked in transparent when there is no votes yet