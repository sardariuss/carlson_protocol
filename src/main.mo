import Types         "Types";
import Decay         "Decay";
import Choice        "Choice";
import Account       "Account";
import LockScheduler "LockScheduler";
import Duration      "Duration";
import Votes         "Votes";

import Map           "mo:map/Map";

import Int           "mo:base/Int";
import Time          "mo:base/Time";
import Principal     "mo:base/Principal";
import Nat64         "mo:base/Nat64";
import Option        "mo:base/Option";
import Buffer        "mo:base/Buffer";

import ICRC1         "mo:icrc1-mo/ICRC1/service";
import ICRC2         "mo:icrc2-mo/ICRC2/service";

shared({ caller = admin }) actor class Carlson({
        deposit_ledger: Principal;
        reward_ledger: Principal;
        lock_parameters: {
            nominal_duration_per_sat: Types.Duration;
            decay_half_life: Types.Duration
        };
        ballot_parameters: {
            min_amount: Nat;
        };
    }) = this {

    // STABLE MEMBERS
    stable let _failed_refunds = Map.new<Principal, [Types.FailedTransfer]>();
    stable let _failed_rewards = Map.new<Principal, [Types.FailedTransfer]>();
    stable let _deposit_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(deposit_ledger));
    stable let _reward_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(reward_ledger));
    stable let _data = {
        register = {
            var index = 0;
            votes = Map.new<Nat, Types.Vote>();
        };
        lock_params = {
            ns_per_sat = Int.abs(Duration.toTime(lock_parameters.nominal_duration_per_sat));
            decay_params = Decay.getDecayParameters({
                half_life = lock_parameters.decay_half_life;
                time_init = Time.now();
            });
        };
    };

    // NON-STABLE MEMBER
    let _votes = Votes.Votes({
        register = _data.register;
        lock_scheduler = LockScheduler.LockScheduler<Types.Ballot>({
            lock_params = _data.lock_params;
            to_lock = Votes.to_lock;
        });
    });

    // Create a new vote (admin only)
    public shared({caller}) func new_vote({
        statement: Text
    }) : async { #Ok : Nat; #Err: { #NotAuthorized }; } {
        if (caller != admin) {
            return #Err(#NotAuthorized);
        };
        #Ok(_votes.new_vote(statement));
    };

    // Add a ballot (vote) on the given vote identified by its vote_id
    public shared({caller}) func vote({
        vote_id: Nat;
        from: ICRC1.Account;
        choice: Types.Choice;
    }) : async { #Ok : Types.Ballot; #Err : ICRC2.TransferFromError or { #NotAuthorized; #VoteNotFound; #AmountTooLow : { min_amount : Nat; }; } } {

        // Check if the caller is the owner of the account
        if (from.owner != caller) {
            return #Err(#NotAuthorized);
        };

        // Check if the amount is not too low
        if (Choice.get_amount(choice) < ballot_parameters.min_amount) {
            return #Err(#AmountTooLow{ min_amount = ballot_parameters.min_amount });
        };

        // Early return if the vote is not found
        if (not _votes.has_vote(vote_id)){
            return #Err(#VoteNotFound);
        };

        let timestamp = Time.now();
        
        let tx_id = switch(await _deposit_ledger.icrc2_transfer_from({
            spender_subaccount = ?Account.pSubaccount(from.owner);
            from;
            to = {
                owner = Principal.fromActor(this);
                subaccount = ?Account.pSubaccount(from.owner);
            };
            amount = Choice.get_amount(choice);
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

        // @todo: instead of potentially trapping, a result shall be returned from "put_ballot"
        // and if an error is returned, one shall transfer back the tokens to the user
        #Ok(_votes.put_ballot({vote_id; tx_id; timestamp; choice; from;}));
    };

    // Unlock the tokens if the duration is reached
    // Return the number of ballots unlocked (whether the transfers succeded or not)
    public func try_unlock() : async Nat {

        let now = Time.now();

        // 1. Try to unlock the tokens
        let unlocks = _votes.try_unlock(now);

        // 2. Trigger the transfers
        // @todo: somehow it seems one can use a type with async as template parameter 
        // but not define a type with async. This prevents from using Buffer.map.
        let transfers = Buffer.Buffer<{
            refund: { args: ICRC1.TransferArgs; call: async ICRC1.TransferResult; };
            reward: { args: ICRC1.TransferArgs; call: async ICRC1.TransferResult; };
        }>(unlocks.size());
        for ({account; refund; reward;} in unlocks.vals()) {

            let refund_args = {
                to = account;
                from_subaccount = ?Account.pSubaccount(account.owner);
                amount = refund - 10; // @todo: need to remove hard-coded fee and fix warning
                fee = null; // Use default fee
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };
            let reward_args = {
                to = account;
                from_subaccount = null;
                amount = reward;
                fee = null;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // @todo: need to add try/catch block
            transfers.add({
                refund = { args = refund_args; call = _deposit_ledger.icrc1_transfer(refund_args); };
                reward = { args = reward_args; call = _reward_ledger.icrc1_transfer(reward_args); };
            });
        };

        // 3. Now wait for the transfers to complete and handle the errors
        for ({ refund; reward; } in transfers.vals()){
            switch(await refund.call){
                case (#Err(error)) {
                    let user_fails = Buffer.fromArray<Types.FailedTransfer>(Option.get(Map.get(_failed_refunds, Map.phash, refund.args.to.owner), []));
                    user_fails.add({ args = refund.args; error; });
                    Map.set(_failed_refunds, Map.phash, refund.args.to.owner, Buffer.toArray(user_fails));
                };
                case (#Ok(_)) {
                };
            };
            switch(await reward.call){
                case (#Err(error)) {
                    let user_fails = Buffer.fromArray<Types.FailedTransfer>(Option.get(Map.get(_failed_rewards, Map.phash, reward.args.to.owner), []));
                    user_fails.add({ args = reward.args; error; });
                    Map.set(_failed_rewards, Map.phash, reward.args.to.owner, Buffer.toArray(user_fails));
                };
                case (#Ok(_)) {
                };
            };
        };

        unlocks.size();
    };

    // Compute the max reward for the given choice to anticipate
    // the reward before voting
    public query func preview_max_reward({
        vote_id: Nat;
        choice: Types.Choice;
    }) : async { #ok: Float; #err: {#VoteNotFound}; } {
        _votes.preview_max_reward({vote_id; choice;});
    };

    // Find a ballot by its vote_id and tx_id
    public query func find_ballot({
        vote_id: Nat; 
        tx_id: Nat;
    }) : async ?Types.Ballot {
        Option.chain(_votes.find_vote(vote_id), func(vote: Types.Vote) : ?Types.Ballot {
            Map.get(vote.locked_ballots, Map.nhash, tx_id);
        });
    };

    // Get the failed refunds for the given principal
    public query func get_failed_refunds(principal: Principal) : async [Types.FailedTransfer] {
        Option.get(Map.get(_failed_refunds, Map.phash, principal), []);
    };

    // Get the failed rewards for the given principal
    public query func get_failed_rewards(principal: Principal) : async [Types.FailedTransfer] {
        Option.get(Map.get(_failed_rewards, Map.phash, principal), []);
    };

};
