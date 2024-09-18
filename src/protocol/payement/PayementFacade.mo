import Types      "../Types";

import Map        "mo:map/Map";

import Int        "mo:base/Int";
import Principal  "mo:base/Principal";
import Result     "mo:base/Result";
import Error      "mo:base/Error";

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

    public type PayServiceError = ICRC2.TransferFromError or { #TransferIncident : { incident_id: Nat; }};
    public type PayServiceResult = Result<TxIndex, PayServiceError>;

    public type IncidentRegister = Types.IncidentRegister;
    public type Service = Types.Service;
    public type ServiceError = Types.ServiceError;
    public type Incident = Types.Incident;
    
    // @todo: is setting created_at_time a good practice?
    public class PayementFacade({
        provider: Principal;
        ledger: ICRC1.service and ICRC2.service;
        incidents: IncidentRegister;
        fee: Nat;
    }){

        public func pay_service({
            from: Account;
            amount: Nat;
            service: Service;
        }) : async* PayServiceResult {

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
                created_at_time = null;
            };

            // Perform the transfer
            let tx_id = switch(await ledger.icrc2_transfer_from(args)){
                case(#Err(error)){ return #err(error); };
                case(#Ok(tx_id)){ tx_id; };
            };
            
            // @todo: will try/catch actually catch traps within the async* block?
            try {
                // Deliver the service
                let { error } = await* service({tx_id});
                switch(error){
                    case(?error) { 
                        let incident = #ServiceFailed({ error; original_transfer = { tx_id; args; }; });
                        #err(#TransferIncident{incident_id = add_incident(incident); });
                    };
                    case(null) {
                        #ok(tx_id);
                    };
                };
            } catch(error){
                let incident = #ServiceTrapped({ error = Error.message(error); original_transfer = { tx_id; args; }; });
                #err(#TransferIncident{incident_id = add_incident(incident); });
            };
        };

        public func send_payement({
            amount: Nat;
            to: Account;
        }) : async* SendPayementResult {

            let args = {
                to;
                from_subaccount = null;
                amount;
                fee = null;
                memo = null;
                created_at_time = null;
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
            let incident_id = incidents.index;
            incidents.index := incident_id + 1;
            Map.set(incidents.incidents, Map.nhash, incident_id, incident);
            incident_id;
        };

        public func get_incidents() : [(Nat, Incident)] {
            Map.toArray(incidents.incidents);
        };

    };

};
