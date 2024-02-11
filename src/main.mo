import Types     "Types";
import Decay     "Decay";
import Account   "Account";
import Locks     "Locks";
import Duration  "Duration";

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

shared actor class GodwinProtocol({
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

    stable let _failed_reimbursements = Map.new<Principal, Map.Map<Nat, FailedReimbursement>>();
    stable let _deposit_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(deposit_ledger));
    stable let _reward_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(reward_ledger));
    stable var _ns_per_sat = Int.abs(Duration.toTime(lock_parameters.nominal_duration_per_sat));
    stable var _decay_params = Decay.getDecayParameters({
        half_life = lock_parameters.decay_half_life;
        time_init = Time.now();
    });

    let _protocol = Locks.Locks({ ns_per_sat = _ns_per_sat; decay_params = _decay_params;});

    public shared({caller}) func lock({
        from: ICRC1.Account; 
        amount: Nat;
    }) : async { #Ok : Nat; #Err : ICRC2.TransferFromError or { #NotAuthorized } } {

        if (from.owner != caller) {
            return #Err(#NotAuthorized);
        };

        let timestamp = Time.now();
        
        let tx_id = switch(await _deposit_ledger.icrc2_transfer_from({
            spender_subaccount = ?Account.pSubaccount(from.owner);
            from;
            to = {
                owner = Principal.fromActor(this);
                subaccount = ?Account.pSubaccount(from.owner);
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

        _protocol.lock({id = tx_id; timestamp; amount; from;});

        #Ok(tx_id);
    };

    // Unlock the tokens if the duration is reached
    public func try_unlock() : async [Nat] {
        
        let to_reimburse = _protocol.try_unlock(Time.now());

        let reimbursed = Buffer.Buffer<Nat>(0);

        for ({id; amount; from;} in Array.vals(to_reimburse)) {

            let args = {
                to = from;
                from_subaccount = ?Account.pSubaccount(from.owner);
                amount = amount - 10; // @todo: need to remove the fee and fix warning
                fee = null; // Use default fee
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // @todo: should try catch on transfer
            // @todo: should parallelize the transfers
            switch(await _deposit_ledger.icrc1_transfer(args)){
                case (#Err(error)) {
                    let inner = Option.get(Map.get(_failed_reimbursements, Map.phash, from.owner), Map.new<Nat, FailedReimbursement>());
                    Map.set(inner, Map.nhash, id, {args; error;});
                    Map.set(_failed_reimbursements, Map.phash, from.owner, inner);
                };
                case (#Ok(tx_id)) {
                    reimbursed.add(tx_id);
                };
            };

        };

        Buffer.toArray(reimbursed);
    };

    public func find_lock(id: Nat) : async ?Locks.TokensLock {
        _protocol.find_lock(id);
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
