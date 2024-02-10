import Types "Types";
import Decay "Decay";
import Account "Account";
import Protocol "Protocol";
import Duration "Duration";

import Map "mo:map/Map";

import Deque "mo:base/Deque";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";

import Prim "mo:prim";

import ICRC1 "mo:icrc1-mo/ICRC1/service";
import ICRC2 "mo:icrc2-mo/ICRC2/service";

// 1. Prevent the rich users to have too much power
//    -> The more tokens locked, the longer the duration
//        -> Problem: it punishes the users who align with the community on what matters
//                    and gives more instant power to the users who don't align with it
//        -> Solution: - reward more the users the longer the lock is
//                     - reward more the users who are right than the users who are wrong at the end of the lock
//                     - reward more if that topic is important compared to other topics (at the time that topic came out?)

// Without reward (notion of sacrifice, good faith)
// - Winning:
//     - people who voted for a topic that matters to the community, the same side as the community
//     - people who voted for a topic that does not matter to the community
// - Losing:
//     - people who voted for a topic that matters to the community, the opposite side as the community


// For godwin, two types of votes:
// - boost vote: put on top the things that matter the most to the community
// - map vote: categorize the topics

// Question: 
// shall the result of the vote at time T always reflect how many tokens are locked in the vote at that moment? what if no tokens are locked in the vote at that moment?

// Similarities in locking mechanism and the reddit hot algorithm

// Basically, sacrifice alone is useless, sacrifice if aligned with others will shape the community, and sacrifice if not aligned with others will do nothing


// Godwin is not really

// The problem with the reward is that you can "game" the system without caring about the topics
// -> Maybe instead of a token as reward, use reputation points?
//
// The game shall not be gameable, in a way that somebody that is only interested in the money shall not win more than somebody who actually cares about the topics


  // I need an algorithm that:
  // 1. Accept tokens from an ICRC-2 ledger canister (transfer_from)
  // 2. Put the token into a specific account whith (principal | prefix | statement_id)
  // -> If not logged with II, how to get the principal?
  // 3. Compute the duration for when this transaction shall be reimbursed
  // -> The more tokens are locked, the more the duration of the lock shall be long for all users that locked tokens!
  // -> The effect of others locking tokens on increasing the duration of the lock for a given user shall be greater
  //    the closer in time the lock is to the time the user locked his tokens
  // -> For now use a hard-coded duration per number of tokens
  //   -> If lock 1 second per satoshi, then 1 btc = 100 000 000 seconds = 1157 days
  //   -> So for 3 seconds per satoshi, 1 btc = 3471 days = 9.5 years
  //   -> With that say, if you put 10 usd (btc/usd = 50 000) you get 0.0002 btc, so 0.6 days
  //   -> With that say, if you put 1 usd (btc/usd = 50 000) you get 0.00002 btc, so 0.06 days, so 1.5 hours
  //   -> With that say, if you put 0.1 usd (btc/usd = 50 000) you get 0.000002 btc, so 0.006 days, so 10 minutes
  //   -> With that say, if you put 0.01 usd (btc/usd = 50 000) you get 0.0000002 btc, so 0.0006 days, so 1 minute



  // TODO:
  // - Add a function that returns the minimum duration for a given amount of tokens
  // - Add ICRC-2 ledger
  // - Add a function that computes the reward for a given lock based on:
  //      - the duration of that lock
  //      - (the amount of tokens locked) : no because time left is already proportional to the amount of tokens locked
  //      - the result of the vote at the end of the lock
  //        -> Problem: what if the answer is obvious, people can just lock tokens and get the reward
  //        -> Solution: the more the distribution of the votes is close to 50/50 during the locking period, the more the reward

  // The reward should be greater the 

  // What was the split at the time you voted ? 

shared actor class GodwinProtocol(ck_btc: Principal, reward_ledger: Principal) = this {

  type Time = Time.Time;

  type FailedReimbursement = {
    args: ICRC1.TransferArgs;
    error: ICRC1.TransferError;
  };

  stable let _failed_reimbursements = Map.new<Principal, Map.Map<Nat, FailedReimbursement>>();
  stable let _ckbtc : ICRC1.service and ICRC2.service = actor(Principal.toText(ck_btc));
  stable let _reward : ICRC1.service and ICRC2.service = actor(Principal.toText(ck_btc));
  stable var _ns_per_sat = Int.abs(Duration.toTime(#MINUTES(5)));
  stable var _decay_params = Decay.getDecayParameters({
    half_life = #DAYS(15);
    time_init = Time.now();
  });

  let _protocol = Protocol.Protocol({ ns_per_sat = _ns_per_sat; decay_params = _decay_params;});

  public shared({caller}) func lock({
    from: ICRC1.Account; 
    amount: Nat;
  }) : async { #Ok : Nat; #Err : ICRC2.TransferFromError or { #NotAuthorized } } {

    if (from.owner != caller) {
      return #Err(#NotAuthorized);
    };

    let timestamp = Time.now();
    
    let tx_id = switch(await _ckbtc.icrc2_transfer_from({
      spender_subaccount = ?Account.toSubaccount(from.owner);
      from;
      to = {
        owner = Principal.fromActor(this);
        subaccount = ?Account.toSubaccount(from.owner);
      };
      amount;
      fee = null; // Use default fee
      memo = null;
      created_at_time = ?Nat64.fromNat(Int.abs(timestamp));
    })){
      case (#Err(err)) {
        return #Err(err);
      };
      case (#Ok(id)) {
        id;
      };
    };

    _protocol.lock({tx_id; timestamp; amount; from;});

    #Ok(tx_id);
  };

  // Unlock the tokens if the duration is reached
  public func try_unlock() : async () {
    
    let to_reimburse = _protocol.try_unlock(Time.now());

    for ({tx_id; amount; from;} in Array.vals(to_reimburse)) {

      let args = {
        to = from;
        from_subaccount = ?Account.toSubaccount(from.owner);
        amount; // @todo: need to remove the fee
        fee = null; // Use default fee
        memo = null;
        created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
      };

      // @todo: should try catch on transfer
      // @todo: should parallelize the transfers
      switch(await _ckbtc.icrc1_transfer(args)){
        case (#Err(error)) {
          let inner = Option.get(Map.get(_failed_reimbursements, Map.phash, from.owner), Map.new<Nat, FailedReimbursement>());
          Map.set(inner, Map.nhash, tx_id, {args; error;});
          Map.set(_failed_reimbursements, Map.phash, from.owner, inner);
        };
        case (#Ok(_)) {};
      };
    };

  };

  public query func get_failed_reimbursements(principal: Principal) : async [(Nat, FailedReimbursement)] {
    Option.getMapped(Map.get(_failed_reimbursements, Map.phash, principal), 
      func(inner: Map.Map<Nat, FailedReimbursement>) : [(Nat, FailedReimbursement)] { 
        Map.toArray(inner); 
      }, 
      []
    );
  };

};
