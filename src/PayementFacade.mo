import Account           "Account";
import Types             "Types";
import MapArray          "utils/MapArray";

import Map               "mo:map/Map";

import Int               "mo:base/Int";
import Time              "mo:base/Time";
import Principal         "mo:base/Principal";
import Nat64             "mo:base/Nat64";
import Result            "mo:base/Result";

import ICRC1             "mo:icrc1-mo/ICRC1/service";
import ICRC2             "mo:icrc2-mo/ICRC2/service";

module {

    type Time = Int;
    type Account = ICRC1.Account;
    type TxIndex = ICRC1.TxIndex;

    type FailedTransfer = Types.FailedTransfer;
    type TransferArgs = Types.TransferArgs;

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type PayementError = ICRC2.TransferFromError or { #NotAuthorized; };
    public type SendPaymentResult = Result<TxIndex, PayementError>;
    
    public type AddDepositError = PayementError or { #DepositTooLow : { min_deposit : Nat; }; };
    public type AddDepositResult = Result<TxIndex, AddDepositError>;

    public type TransferResult = Result<Nat, ICRC1.TransferError>;
    public type TransferError = ICRC1.TransferError;
    
    // @todo: is setting created_at_time a good practice?
    public class PayementFacade({
        payee: Principal;
        ledger: ICRC1.service and ICRC2.service;
        failed_transfers: Map.Map<Principal, [FailedTransfer]>;
        min_deposit: Nat;
        fee: ?Nat;
    }){

        public func send_payement({
            caller: Principal;
            from: Account;
            amount: Nat;
            time: Time;
        }) : async* Result<Nat, ICRC2.TransferFromError or { #NotAuthorized; }> {
            
            // Transfer to the payee's main account (null subaccount)
            await* transfer_from({
                caller;
                from;
                amount;
                time;
                to_subaccount = null;
            });
        };

        public func add_deposit({
            caller: Principal;
            from: Account;
            amount: Nat;
            time: Time;
        }) : async* AddDepositResult {

            if (amount < min_deposit) {
                return #err(#DepositTooLow{ min_deposit; });
            };

            // Transfer to the payee's user subaccount
            await* transfer_from({
                caller;
                from;
                amount;
                time;
                to_subaccount = ?Account.pSubaccount(caller);
            });
        };

        public func refund_deposit({
            amount: Nat;
            origin_account: Account;
            time: Time;
        }) : async* TransferResult {

            await* transfer({
                amount;
                to = origin_account;
                time;
                from_subaccount = ?Account.pSubaccount(origin_account.owner);
            });
        };

        public func grant_reward({
            amount: Nat;
            to: Account;
            time: Time;
        }) : async* TransferResult {
            
            await* transfer({
                amount;
                to;
                time;
                from_subaccount = null;
            });
        };

        func transfer_from({
            caller: Principal;
            from: Account;
            amount: Nat;
            time: Time;
            to_subaccount: ?Blob;
        }) : async* Result<Nat, ICRC2.TransferFromError or { #NotAuthorized; }> {
            
            // Check if the caller is the owner of the account
            if (from.owner != caller) {
                return #err(#NotAuthorized);
            };
            
            to_base_result(await ledger.icrc2_transfer_from({
                spender_subaccount = ?Account.pSubaccount(from.owner);
                from;
                to = {
                    owner = payee;
                    subaccount = to_subaccount;
                };
                amount;
                fee;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(time));
            }));
        };

        func transfer({
            amount: Nat;
            to: Account;
            from_subaccount: ?Blob;
            time: Time;
        }) : async* TransferResult {

            let args = {
                to;
                from_subaccount;
                amount;
                fee;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(time));
            };
        
            let transfer = to_base_result(await ledger.icrc1_transfer(args));

            switch(transfer){
                case(#err(error)){
                    MapArray.add(failed_transfers, Map.phash, to.owner, { args; error; });
                };
                case(_){};
            };

            transfer;
        };

    };

    func to_base_result<Ok, Err>(icrc1_result: { #Ok: Ok; #Err: Err}) : Result<Ok, Err> {
        switch(icrc1_result){
            case(#Ok(ok)) {
                #ok(ok);
            };
            case(#Err(err)) {
                #err(err);
            };
        };
    };

};
