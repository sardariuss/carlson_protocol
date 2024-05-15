# The Carlson Protocol

*My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong [...] If you pay enough attention you can rate your own performance, just as if you're betting on sports [...] To tell the truth is my main view and I plan to do that to the best of my ability.*
> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM_O80?si=bSkrQ0C2GeTJe7TV&t=118)

## A decision protocol for seeking the truth

The Carlson Protocol is a decentralized voting system where people vote using bitcoins. These bitcoins are transferred back to the user after a period of time that can vary according to specific rules. When reimbursed, users get rewarded with additional tokens that depend on how their past vote aligns with the current view.

✨ **The Carlson Protocol leverages how much people care**. If you don't care enough about a vote, you will find better usage for your bitcoins elsewhere.

⚔️ **The Carlson Protocol is a double-edged sword**. The more bitcoins you lock in a vote, the greater your voice, but the lesser the reward and the longer your bitcoins will stay locked.

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
- `parameters.hotness_half_life`: used to compute the effect of other ballots on a given ballot to update the lock date, so that the shorter (resp. the longer) the timespan between the date of that ballot and the others, the more (resp. the less) time is added to the ballot's lock.
- `parameters.ballot_min_amount`: the minimum amount a voter has to lock in order to vote.

## 🚧 Roadmap

### Q2 2024: MVP

For end of Q2, we'd like to have a local functional MVP where users can participate to votes, create new votes, and appreciate the reward mechanisms of the Carlson protocol through a minimal front-end.

#### Features:

- BACKEND
  - *DONE* time dilation curve: shall replace the current nominal_duration_per_sat. It aims at preventing absurd locking times (e.g. 10 seconds or 100 years). Curve formula would probably be ax^b, where a=3 (days), and b=ln(2)/ln(10). This way, a hot score of 1 sat would yield 3 days lock, 10 sats a 6 days lock, ... 1 btc a 1 year lock.
  - *DONE* vote proposal, so that everybody can propose a new vote.
  - *SKIPPED* vote metadata, so that the Carlson protocol canister can be used as a service separated from any other backend/frontend canisters, but still allows to save and retrieve specific votes.
  - *DONE* vote decay over time (so it gets easier to challenge consensus overtime)

- FRONTEND:
  - II login + ckBTC account + Carlson (reward token) account
  - display the list of votes (ordered by date)
  - vote details: total amount locked, current vote results, current lock duration
  - put ballot: select 'AYE'/'NAY', input number of satoshis, preview lock duration, preview contest multiplier, place the vote
  - profile page: list of current locks with amount and time left, list of old locks with amount won

#### Challenges:
  
  - Manage to convey how the protocol works in the UI
  - Make a functional test scenario with many users and votes, manage the balances of each user
  - The Carlson' protocol relies on conditions on time and durations, which kind be tricky to reproduce in a test

### Later

- BACKEND
  - create and parametrize the Carlson ledger (new token). For this, we need to implement the logic for 3) and 4). In the Carlson protocol, the reward shall be proportional to to:
        1) the contest multiplier of the ballot, determined at the start of the lock
        2) the vote results, determined at the end of the lock
        3) the proportion of the ballot's ckBTC amount compared to the overall ckBTC amount of tokens locked in the protocol for the duration of that lock.
        4) the minting velocity of the token (set to be halved every 2 years or so).
  - to justify: why use a linear function for the contest factor, and a logistic regression for the score?
- FRONTEND
  - Plug login

### Misc TODOs

- Fix initial contest multiplier: 0.5 shall decrease the more tokens are locked with the first ballot
- The protocol canister shall be the owner of the ledger canister
- Be able to order the votes by date, popularity or hotness. Be able to filter them by tag.
- Add reward for users who suggest votes
- Remove prints in LockScheduler.mo
- Add votes unit tests
- If a transfer fails, it is added to the map of failed transfers, but its origin is lost
- Investigate if all the scenarios involving async calls could not leave an intermediate state (e.g. payement done but ballot not added)


### REFAC
- could do a RAII like transfer function (with_transfer(callback)) that leaves a trace if a transfer succeed but callback fails
- could use a MapUpdated function so one only need a single map for ballots and deposits while stile being able to split the responsabilities