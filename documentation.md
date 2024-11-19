---
description: >-
  The Carlson Protocol is a decentralized system designed to gauge and represent
  consensus on factual topics through collective input.
icon: sunglasses
---

# Documentation

### Goals

🎯 **Two primary objectives**:

* Provide an **accurate representation of the current consensus**—capturing its nuances as probabilities rather than binary outcomes.
* Incentivize skilled participants to **contribute genuine opinions** and help establish consensus.

💪 **Two major strengths**:

* **Immune to bribery**: bribery is a timeless issue. Whenever human decisions can be influenced by money, the risk of manipulation arises.
* **Values user attention**: capturing voters' attention becomes increasingly difficult as the number or the complexity of topics grows.

### How It Works

⚖️ **Stake-weighted voting**: Users lock Bitcoin to cast votes on specific statements. The weight of their vote corresponds directly to the amount of Bitcoin they lock.

♾️ **Continuous voting**: Votes do not have a fixed end date. The lock duration for each vote is independent and varies based on the vote’s popularity at the time the lock is placed.

🎁 **Rewards**: The protocol uses two tokens: one to reward participants for their engagement and the other for their insight.

### Incentives

🌌 **Presence token**: Rewards users based on their engagement.

* **Daily minting**: A fixed amount of tokens is minted daily.
* **Distribution**: Two thirds go to the voters proportional to the amount of token locked. The rest is allocated to the vote creators, based on the popularity of their votes.

🔮 **Resonance token**: Rewards voters based on how accurate their vote aligns with the consensus at the time of unlock.

$$
resonance = amount * dissent[t_0]*consent[t]
$$

* Where:
  * `amount`: Bitcoins locked by the user.
  * `dissent_t_0`: opposite\_tokens / total\_tokens at the time of locking.
  * `consent_t`: same\_tokens / total\_tokens at the time of unlocking.

### Lock Duration

⏳ **Flexible lock duration**: The duration depends on the vote’s popularity _around_ the time the ballot is placed such that the more tokens locked, the longer the lock duration. Notice that this also applies for tokens that are locked after yours so the duration of your lock will increase if the popularity of the vote increases after your vote.

📈 **Time dilation curve**: A time dilation curve maps the amount of locked tokens to a specific duration, ensuring durations remain within a reasonable range (e.g., between one month and a few years) for locks ranging from 100 satoshis to thousands of Bitcoins.

### Game Theory

🗳️ **Rewards the bold**: Minority opinions have stronger incentives to express themselves but the consensus still has to shift before their lock expires.

♟️ **Strategic voting dynamics**: Casting a vote creates opportunities for opponents to counter, but it also increases the stakes by lengthening the lock duration.

🐋 **Whale influence**: Large stakeholders can rapidly shift consensus by locking substantial amounts. However, this creates a longer window of opportunity for the opposing side to respond.

💡 **Wittgenstein’s indicator**: _"\[...] if you use a ruler to measure a table you may also be using the table to measure the ruler"_. The protocol could feature an indicator to flag votes with either too few or too many tokens locked, signaling that such votes may not reflect a reliable consensus.
