import Types             "Types";
import Subaccount        "Subaccount";

import Map               "mo:map/Map";

import Int               "mo:base/Int";
import Time              "mo:base/Time";
import Principal         "mo:base/Principal";
import Nat64             "mo:base/Nat64";
import Result            "mo:base/Result";
import Error             "mo:base/Error";

import ICRC1             "mo:icrc1-mo/ICRC1/service";
import ICRC2             "mo:icrc2-mo/ICRC2/service";

module {

    type Time = Int;
    type Account = ICRC1.Account;
    type TxIndex = ICRC1.TxIndex;

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type ErrorCode = Error.ErrorCode;

    public type SendPayementError = { incident_id: Nat; };
    public type SendPayementResult = Result<TxIndex, SendPayementError>;

    public type PayServiceError = ICRC2.TransferFromError or { #NotAuthorized; } or { #Incident : { incident_id: Nat; }};
    public type PayServiceResult = Result<TxIndex, PayServiceError>;

    public type IncidentRegister = Types.IncidentRegister;
    public type Service = Types.Service;
    public type ServiceTrappedError = Types.ServiceTrappedError;
    public type Incident = Types.Incident;
    
    // @todo: is setting created_at_time a good practice?
    public class PayementFacade({
        provider: Principal;
        ledger: ICRC1.service and ICRC2.service;
        incident_register: IncidentRegister;
        fee: ?Nat;
    }){

        public func pay_service({
            caller: Principal;
            from: Account;
            amount: Nat;
            time: Time;
            to_subaccount: ?Blob;
            service: Service;
        }) : async* PayServiceResult {
            
            // Check if the caller is the owner of the account
            if (from.owner != caller) {
                return #err(#NotAuthorized);
            };

            let args = {
                spender_subaccount = ?Subaccount.from_principal(from.owner); // @todo: not sure about that
                from;
                to = {
                    owner = provider;
                    subaccount = to_subaccount;
                };
                amount;
                fee;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(time));
            };

            // Perform the transfer
            let tx_id = switch(await ledger.icrc2_transfer_from(args)){
                case(#Ok(tx_id)){ tx_id; };
                case(#Err(error)){ return #err(error); };
            };
            
            // Deliver the service
            try {
                #ok(await* service(tx_id));
            } catch(error){
                let incident = #ServiceTrapped({ error_code = Error.code(error); original_transfer = { tx_id; args; }; });
                #err(#Incident{incident_id = add_incident(incident); });
            };
        };      

        public func send_payement({
            amount: Nat;
            to: Account;
            from_subaccount: ?Blob;
            time: Time;
        }) : async* SendPayementResult {

            let args = {
                to;
                from_subaccount;
                amount;
                fee;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(time));
            };

            // Perform the transfer
            let error = try {
                switch(await ledger.icrc1_transfer(args)){
                    case(#Ok(tx_id)){ return #ok(tx_id); };
                    case(#Err(error)){ error; };
                };
            } catch(err) {
                #Trapped{ error_code = Error.code(err); };
            };

            // Add the incident
            let incident_id = add_incident(#TransferFailed{ args; error; });
            #err({incident_id});
        };

        func add_incident(incident: Incident) : Nat {
            let incident_id = incident_register.index;
            incident_register.index := incident_id + 1;
            Map.set(incident_register.incidents, Map.nhash, incident_id, incident);
            incident_id;
        };

    };

};
