import DepositScheduler "DepositScheduler";
import Types            "../Types";
import Decay            "../Decay";
import LedgerFacade     "../LedgerFacade";

import Map              "mo:map/Map";

import Option           "mo:base/Option";
import Debug            "mo:base/Debug";
import Buffer           "mo:base/Buffer";

module {

    type Account = Types.Account;
    type DecayModel = Decay.DecayModel;
    type DepositScheduler = DepositScheduler.DepositScheduler;
    type LockedDeposit = DepositScheduler.LockedDeposit;
    type TransferResult = LedgerFacade.TransferResult;

    type LockedAccount = {
        account: Account;
    };

    type Time = Int;
    type AddDepositResult = LedgerFacade.AddDepositResult;

    public class DepositController({
        map_deposits: Map.Map<Nat, Map.Map<Nat, LockedDeposit>>;
        ledger: LedgerFacade.LedgerFacade;
        decay_model: DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }) {

        let _deposit_scheduler = DepositScheduler.DepositScheduler({ ledger; decay_model; get_lock_duration_ns; });

        public func new_map_deposits(map_id: Nat) {
            let old = Map.add(map_deposits, Map.nhash, map_id, Map.new<Nat, LockedDeposit>());
            
            if (Option.isSome(old)){
                Debug.trap("A lock map with the ID " # debug_show(map_id) # " already exists");
            };
        };

        public func add_deposit({
            map_id: Nat;
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async AddDepositResult {
            
            // Get the deposits
            let deposits = switch(Map.get(map_deposits, Map.nhash, map_id)){
                case(null) { Debug.trap("Lock map not found"); };
                case(?v) { v };
            };

            // Add the deposit
            await _deposit_scheduler.add_deposit({ deposits; caller; account; amount; timestamp; });
        };

        public func try_refund(time: Time) : Map.Map<Nat, [async* TransferResult]> {
            
            let to_refund = Map.new<Nat, [TransferCallback]>();

            for ((map_id, deposits) in Map.entries(map_deposits)){
                let transfer_callbacks = _deposit_scheduler.try_refund(deposits, time);
                if (transfer_callbacks.size() > 0){
                    Map.set(to_refund, Map.nhash, map_id, Buffer.toArray(transfer_callbacks));
                };
            };

            to_refund;
        };

    };
}