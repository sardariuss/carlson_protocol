import DepositScheduler "DepositScheduler";
import Types            "../Types";
import Decay            "../Decay";
import PayementFacade   "../PayementFacade";

import Map              "mo:map/Map";

import Option           "mo:base/Option";
import Debug            "mo:base/Debug";
import Buffer           "mo:base/Buffer";

module {

    type Account = Types.Account;
    type DecayModel = Decay.DecayModel;
    type DepositScheduler = DepositScheduler.DepositScheduler;
    type LockedDeposit = DepositScheduler.LockedDeposit;
    type TransferResult = PayementFacade.TransferResult;

    type LockedAccount = {
        account: Account;
    };

    type Time = Int;
    type AddDepositResult = PayementFacade.AddDepositResult;
    type TransferCallback = DepositScheduler.TransferCallback;

    public class DepositController({
        map_deposits: Map.Map<Nat, Map.Map<Nat, LockedDeposit>>;
        deposit_scheduler: DepositScheduler;
    }) {

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
        }) : async* AddDepositResult {
            
            // Get the deposits
            let deposits = switch(Map.get(map_deposits, Map.nhash, map_id)){
                case(null) { Debug.trap("Lock map not found"); };
                case(?v) { v };
            };

            // Add the deposit
            await* deposit_scheduler.add_deposit({ deposits; caller; account; amount; timestamp; });
        };

        public func try_refund(time: Time) : async* [TransferResult] {
            
            // Trigger all the refunds
            let transfers = Buffer.Buffer<async* TransferResult>(0);
            for ((map_id, deposits) in Map.entries(map_deposits)){
                for (callback in deposit_scheduler.try_refund(deposits, time).vals()){
                    transfers.add(callback());
                };
            };

            // Wait for the results
            let results = Buffer.Buffer<TransferResult>(transfers.size());
            for (transfer in transfers.vals()){
                results.add(await* transfer);
            };
            Buffer.toArray(results);
        };

    };
}