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

## Protocol parameters

- `deposit_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the ballots (aims to be ckBTC)
- `reward_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the rewards
- `nominal_duration_per_sat`: used to deduce the initial locking duration from the amount of satoshis transfered with the vote. Aimed to be updated programmatically based on demand or modified by a DAO.
- `decay_half_life`: used to compute the effect of other ballots on a given ballot to update the lock date, so that the shorter (resp. the longer) the timespan between the date of that ballot and the others, the more (resp. the less) time is added to the ballot's lock. Aimed to be modified by a DAO.
- `ballot_minimum_amount`: the minimum amount a voter has to lock in order to vote.

## Roadmap

- Add a timer to periodically call try_unlock
- Add decay on votes result
- Create complex e2e scenarios
- Start building a UI
- TBD

## 🚧 Misc notes (to clean)

The protocol prevents the rich users to have too much power
   -> The more tokens locked, the longer the duration
       -> Problem: it punishes the users who align with the community on what matters
                   and gives more instant power to the users who don't align with it
       -> Solution: - reward more the users the longer the lock is
                    - reward more the users who are right than the users who are wrong at the end of the lock
                    - reward more if that topic is important compared to other topics (at the time that topic came out?)

Without reward (notion of sacrifice, good faith)
- Winning:
    - people who voted for a topic that matters to the community, the same side as the community
    - people who voted for a topic that does not matter to the community
- Losing:
    - people who voted for a topic that matters to the community, the opposite side as the community

Basically, sacrifice alone is useless, sacrifice if aligned with others will shape the community, and sacrifice if not aligned with others will do nothing.

POSSIBLE ABUSES:
  When nobody voted yet, it gets possible to "shotgun" the statement if is too obvious, making it a "sure reward" of c=0.5
    -> Fix 1: Have the selection of statement done by DAO or other process so that they cannot be too obvious
    -> Fix 2: Have a starting period during which the votes are not revealed, at the end of which the c is determined based on the proportion of votes
  At anytime, it is possible to get a reward of 0.25 by alternating votes of YES and NO so that whichever side "wins" at the end, half of the tokens locked will get you c=0.5
    -> It could artificially increase the number of divisive votes (close to 50/50), but the more divise and the more tokens are locked, the greater the opportunity for people who cares to jump in (especially poor ones)
    -> If most users are only there for the rewards, it is always possible to diminish the reward (and keep more for the owners)

PHILOSOPHY:

Justification behind the exp decay for the locking time
  1. People shall not have their tokens locked for an inifinite amount of time
  2. The more tokens are locked overall, the longer the locking period for individuals
  3. The longer the locking period for individuals, the greater the opportunity for other individuals to vote and alter the reward

Reward too late or too soon ?
-> if an important vote (how many people are voting), shall be later
-> if a disputed vote, shall be later
    -> normally disputed votes will attract more people (because of incentives), so shall automatically make the locking period more long

-> Could just use the logarithmic amount of tokens
    -> No, because logarthmic of tokens from the beginning ? If you assume a topic had had a lot of traction in the past, then it over, and you want to revive it, you might stuck your tokens in it while you're alone wanting to revive it
Overall it is up to the voter to understand when "the crowd" is mature enough, or ready enough to change its mind about a topic.

Boost potentail reward gives the opprtunity for somebody to contest that, like an "arbitrage".

UI REQUIREMENTS:
  General:
    - ms_per_sat
    - decay half life

  Statement specific:
    - total votes both sides (=cumulated)
    - current amount tokens locked

  User specific:
    When about to lock tokens, you need to get:
      - minimum locking time
      - maximum reward (maximum reward you will get if at the end of the locking period, the result is the same as your vote)
    Once tokens are locked, you need to have:
      - updated (minimum) locking time remaining (or date)
      - current reward
      - potential reward