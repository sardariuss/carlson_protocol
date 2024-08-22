import Types      "../Types";
import Subaccount "Subaccount";

import Map        "mo:map/Map";

import Int        "mo:base/Int";
import Time       "mo:base/Time";
import Principal  "mo:base/Principal";
import Nat64      "mo:base/Nat64";
import Result     "mo:base/Result";
import Error      "mo:base/Error";
import Debug      "mo:base/Debug";

import ICRC1      "mo:icrc1-mo/ICRC1/service";
import ICRC2      "mo:icrc2-mo/ICRC2/service";

module {

    type Time = Int;
    type Account = ICRC1.Account;
    type TxIndex = ICRC1.TxIndex;

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type ErrorCode = Error.ErrorCode;

    public type SendPayementError = { incident_id: Nat; };
    public type SendPayementResult = Result<TxIndex, SendPayementError>;

    public type PayServiceError = ICRC2.TransferFromError or { #Incident : { incident_id: Nat; }};
    public type PayServiceResult = Result<TxIndex, PayServiceError>;

    public type IncidentRegister = Types.IncidentRegister;
    public type Service = Types.Service;
    public type ServiceError = Types.ServiceError;
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
            
            Debug.print("ledger: " # debug_show(Principal.fromActor(ledger)));
            Debug.print("caller: " # debug_show(caller));
            Debug.print("from account: " # debug_show(from));
            Debug.print("to subaccount: " # debug_show(to_subaccount));

            let args = {
                // According to the ICRC2 specifications, if the from account has been approved with a
                // different spender subaccount than the one specified, the transfer will be rejected.
                spender_subaccount = null;//?Subaccount.from_principal(caller);
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
                case(#Err(error)){ return #err(error); };
                case(#Ok(tx_id)){ tx_id; };
            };
            
            try {
                // Deliver the service
                let { error } = await* service({tx_id});
                switch(error){
                    case(?error) { 
                        let incident = #ServiceFailed({ error; original_transfer = { tx_id; args; }; });
                        #err(#Incident{incident_id = add_incident(incident); });
                    };
                    case(null) {
                        #ok(tx_id);
                    };
                };
            } catch(error){
                let incident = #ServiceTrapped({ error = Error.message(error); original_transfer = { tx_id; args; }; });
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
