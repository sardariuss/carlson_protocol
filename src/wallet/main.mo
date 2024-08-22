import Principal "mo:base/Principal";
import Blob      "mo:base/Blob";
import Buffer    "mo:base/Buffer";
import Debug     "mo:base/Debug";
import Nat64     "mo:base/Nat64";
import Int       "mo:base/Int";
import Time      "mo:base/Time";

import Protocol  "canister:protocol";
import ckBTC     "canister:ck_btc";


shared actor class Wallet() = this {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };
    type ApproveResult = {
        #Ok: Nat;
        #Err: ckBTC.ApproveError;
    };

    public query({ caller }) func get_account() : async Account {
        user_account(caller);
    };

    public composite query({ caller }) func get_balance() : async Nat {
        await ckBTC.icrc1_balance_of(user_account(caller));
    };

    public shared({ caller }) func approve_protocol({
        amount: Nat;
        expected_allowance: ?Nat;
        expires_at: ?Nat64;
    }) : async ApproveResult {
        await ckBTC.icrc2_approve({
            fee = null; // @todo: what fee ?
            memo = null; // @todo: what memo ?
            from_subaccount = ?from_principal(caller);
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            amount;
            expected_allowance;
            expires_at;
            spender = protocol_locks_account();
        });
    };

    public composite query({ caller }) func protocol_allowance() : async ckBTC.Allowance {
        Debug.print("caller: " # debug_show(caller));
        Debug.print("from account: " # debug_show(user_account(caller)));
        await ckBTC.icrc2_allowance({
            account = user_account(caller);
            spender = protocol_locks_account();
        });
    };

    func user_account(principal: Principal) : Account {
        { owner = Principal.fromActor(this); subaccount = ?from_principal(principal) };
    };

    func protocol_locks_account() : Account {
        { owner = Principal.fromActor(Protocol); subaccount = null };
    };

    // @todo: to unite with method from Subaccount.mo in the protocol
    func from_principal(principal: Principal) : Blob {
        let blob_principal = Blob.toArray(Principal.toBlob(principal));
        // According to IC interface spec: "As far as most uses of the IC are concerned they are
        // opaque binary blobs with a length between 0 and 29 bytes"
        if (blob_principal.size() > 32) {
            Debug.trap("Cannot convert principal to subaccount: principal length is greater than 32 bytes");
        };
        let buffer = Buffer.Buffer<Nat8>(32);
        buffer.append(Buffer.fromArray(blob_principal));
        finalize_subaccount(buffer);
    };

    func finalize_subaccount(buffer : Buffer.Buffer<Nat8>) : Blob {
        // Add padding until 32 bytes
        while(buffer.size() < 32) {
            buffer.add(0);
        };
        // Verify the buffer is 32 bytes
        assert(buffer.size() == 32);
        // Return the buffer as a blob
        Blob.fromArray(Buffer.toArray(buffer));
    };

};