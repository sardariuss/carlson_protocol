import DepositScheduler "DepositScheduler";
import Types            "../Types";
import Decay            "../Decay";
import PayementFacade   "../PayementFacade";

import Map              "mo:map/Map";

import Debug            "mo:base/Debug";
import Buffer           "mo:base/Buffer";

module {

    type Account = Types.Account;
    type DecayModel = Decay.DecayModel;
    type DepositScheduler = DepositScheduler.DepositScheduler;
    public type Register = DepositScheduler.Register;
    type TransferResult = PayementFacade.TransferResult;

    type LockedAccount = {
        account: Account;
    };

    type Time = Int;
    type AddDepositResult = PayementFacade.AddDepositResult;

    public class DepositController({
        registers: Map.Map<Nat, Register>;
        deposit_scheduler: DepositScheduler;
    }) {

        public func new_deposit_register(register_id: Nat) {

            if (Map.has(registers, Map.nhash, register_id)){
                Debug.trap("A deposit register with the ID " # debug_show(register_id) # " already exists");
            };

            Map.set(registers, Map.nhash, register_id, DepositScheduler.new_register(register_id));
        };

        public func add_deposit({
            register_id: Nat;
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {
            
            // Get the register
            let register = switch(Map.get(registers, Map.nhash, register_id)){
                case(null) { Debug.trap("Deposit register not found"); };
                case(?v) { v };
            };

            // Add the deposit
            await* deposit_scheduler.add_deposit({ register; caller; account; amount; timestamp; });
        };

        type RefundInfo = {
            register_id: Nat;
            original_tx_id: Nat;
        };

        public func try_refund(time: Time) : async* [RefundInfo] {
            
            let refunds = Buffer.Buffer<RefundInfo>(0);

            // Trigger all the refunds
            for (register in Map.vals(registers)){
                let tx_ids = Buffer.fromArray<Nat>(await* deposit_scheduler.try_refund(register, time));
                refunds.append(Buffer.map(tx_ids, func(tx_id: Nat) : RefundInfo { { register_id = register.id; original_tx_id = tx_id; } }));
            };

            Buffer.toArray(refunds);
        };

    };
}