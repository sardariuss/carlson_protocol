import Types      "../Types";

import Int        "mo:base/Int";
import Principal  "mo:base/Principal";
import Result     "mo:base/Result";
import Error      "mo:base/Error";
import Time       "mo:base/Time";
import Nat64      "mo:base/Nat64";

import ICRC1      "mo:icrc1-mo/ICRC1/service";
import ICRC2      "mo:icrc2-mo/ICRC2/service";

module {

    type Time = Int;
    type Account = ICRC1.Account;
    type TxIndex = ICRC1.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ErrorCode = Error.ErrorCode;
    type Transfer = Types.Transfer;
    type TransferFromError = ICRC2.TransferFromError;
    
    public class LedgerFacade({
        provider: Principal;
        ledger: ICRC1.service and ICRC2.service;
        fee: Nat;
    }){

        public func transfer_from({
            from: Account;
            amount: Nat
        }) : async* Result<TxIndex, TransferFromError> {

            let args = {
                // According to the ICRC2 specifications, if the from account has been approved with a
                // different spender subaccount than the one specified, the transfer will be rejected.
                spender_subaccount = null;
                from;
                to = {
                    owner = provider;
                    subaccount = null;
                };
                amount = amount + fee;
                fee = null;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // Perform the transfer
            // @todo: can this trap ?
            switch(await ledger.icrc2_transfer_from(args)){
                case(#Err(error)){ #err(error); };
                case(#Ok(tx_id)){ #ok(tx_id); };
            };
        };

        public func transfer({
            amount: Nat;
            to: Account;
        }) : async* Transfer {

            let args = {
                to;
                from_subaccount = null;
                amount;
                fee = null;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // Perform the transfer
            let result = try {
                switch(await ledger.icrc1_transfer(args)){
                    case(#Ok(tx_id)){ #ok(tx_id); };
                    case(#Err(error)){ #err(error); };
                };
            } catch(err) {
                #err(#Trapped{ error_code = Error.code(err); });
            };

            { args; result; };
        };

    };

};
