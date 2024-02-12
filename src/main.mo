import Types     "Types";
import Decay     "Decay";
import Ballot    "Ballot";
import Account   "Account";
import Locks     "Locks";
import Duration  "Duration";
import Votes     "Votes";

import Map       "mo:map/Map";

import Deque     "mo:base/Deque";
import List      "mo:base/List";
import Nat       "mo:base/Nat";
import Float     "mo:base/Float";
import Int       "mo:base/Int";
import Time      "mo:base/Time";
import Principal "mo:base/Principal";
import Nat64     "mo:base/Nat64";
import Array     "mo:base/Array";
import Option    "mo:base/Option";
import Buffer    "mo:base/Buffer";

import ICRC1     "mo:icrc1-mo/ICRC1/service";
import ICRC2     "mo:icrc2-mo/ICRC2/service";

shared({ caller = admin }) actor class GodwinProtocol({
        deposit_ledger: Principal;
        reward_ledger: Principal;
        lock_parameters: {
            nominal_duration_per_sat: Types.Duration;
            decay_half_life: Types.Duration
        };
    }) = this {

    type Time = Time.Time;

    type FailedReimbursement = {
        args: ICRC1.TransferArgs;
        error: ICRC1.TransferError;
    };

    // STABLE
    stable let _failed_reimbursements = Map.new<Principal, Map.Map<Nat, FailedReimbursement>>();
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

    // NON-STABLE
    let _votes = Votes.Votes(_data);

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
        ballot: Types.Ballot;
    }) : async { #Ok : Nat; #Err : ICRC2.TransferFromError or { #NotAuthorized; #VoteNotFound; } } {

        // Check if the caller is the owner of the account
        if (from.owner != caller) {
            return #Err(#NotAuthorized);
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
            amount = Ballot.get_amount(ballot);
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

        _votes.put_ballot({vote_id; tx_id; timestamp; ballot; from;});

        #Ok(tx_id);
    };

    // Unlock the tokens if the duration is reached
    // @todo: return a result with the successful and failed unlocks
    public func try_unlock() : async [Nat] {

        let now = Time.now();

        let unlocks = Buffer.Buffer<Types.TokensLock>(0);
        let reimbursed = Buffer.Buffer<Nat>(0);

        for (vote in _votes.iter()) {
            let locks = Locks.Locks({ lock_params = _data.lock_params; locks = vote.locks; });
            unlocks.append(locks.try_unlock(now));
        };

        for ({tx_id; ballot; from;} in unlocks.vals()) {

            let args = {
                to = from;
                from_subaccount = ?Account.pSubaccount(from.owner);
                amount = Ballot.get_amount(ballot) - 10; // @todo: need to remove hard-coded fee and fix warning
                fee = null; // Use default fee
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // @todo: should try catch on transfer
            // @todo: should parallelize the transfers
            switch(await _deposit_ledger.icrc1_transfer(args)){
                case (#Err(error)) {
                    let inner = Option.get(Map.get(_failed_reimbursements, Map.phash, from.owner), Map.new<Nat, FailedReimbursement>());
                    Map.set(inner, Map.nhash, tx_id, {args; error;});
                    Map.set(_failed_reimbursements, Map.phash, from.owner, inner);
                };
                case (#Ok(tx_id)) {
                    reimbursed.add(tx_id);
                };
            };

        };

        Buffer.toArray(reimbursed);
    };

    public func find_lock({
        vote_id: Nat; 
        tx_id: Nat;
    }) : async ?Types.TokensLock {
        Option.chain(_votes.find_vote(vote_id), func(vote: Types.Vote) : ?Types.TokensLock {
            Map.get(vote.locks, Map.nhash, tx_id);
        });
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
