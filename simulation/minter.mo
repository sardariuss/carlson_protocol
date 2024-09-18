import ckBTC "canister:ck_btc";

shared actor class Minter() {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    public func mint({amount: Nat; to: Account}) : async ckBTC.TransferResult {
        await ckBTC.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

};