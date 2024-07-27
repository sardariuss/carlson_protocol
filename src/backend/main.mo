import ProtocolTypes "../protocol/Types";

import Map "mo:map/Map";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";


import Protocol "canister:protocol";
import ckBTC "canister:ck_btc";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type SVoteType = ProtocolTypes.SVoteType;
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate> and {
        text: ?Text;
    };
    type Account = { 
        owner : Principal; 
        subaccount : ?Blob;
    };
    type ApproveResult = {
        #Ok: Nat;
        #Err: ckBTC.ApproveError;
    };

    let _texts = Map.new<Nat, Text>();

    public shared({ caller }) func add_grunt(text: Text) : async ?SYesNoVote {
        if (Principal.isAnonymous(caller)){
            return null;
        };
        switch(await Protocol.new_vote({ type_enum = #YES_NO })){
            case(#YES_NO(vote)) {
                Map.set(_texts, Map.nhash, vote.vote_id, text); 
                ?{ vote with text = ?text; };
            };
        };
    };

    public composite query func get_grunts() : async [SYesNoVote] {
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); });
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    { vote with text = Map.get<Nat, Text>(_texts, Map.nhash, vote.vote_id); };
                };
            };
        });
    };

    public query({ caller }) func user_account() : async Account {
        { owner = Principal.fromActor(this); subaccount = ?from_principal(caller)};
    };

    public shared({ caller }) func user_approve({
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
            spender = { owner = Principal.fromActor(Protocol); subaccount = null; };
        });
    };

    public composite query({ caller }) func user_allowance() : async ckBTC.Allowance {
        await ckBTC.icrc2_allowance({
            account = { owner = Principal.fromActor(this); subaccount = ?from_principal(caller); };
            spender = { owner = Principal.fromActor(Protocol); subaccount = null; };
        });
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