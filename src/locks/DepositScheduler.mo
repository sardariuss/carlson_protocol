import LockScheduler "LockScheduler";
import Types "../Types";
import Decay "../Decay";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Option "mo:base/Option";
import Debug  "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";

module {

    type DecayModel = Decay.DecayModel;
    type Account = Types.Account;
    type Lock<T> = LockScheduler.Lock<T>;
    type Buffer<T> = Buffer.Buffer<T>;

    type LockedAccount = {
        account: Account;
    };
    public type LockedDeposit = Lock<LockedAccount>;

    type Time = Int;
    type AddDepositResult = PayementFacade.AddDepositResult;
    type TransferResult = PayementFacade.TransferResult;
    public type TransferCallback = () -> async* PayementFacade.TransferResult;

    public class DepositScheduler({
        payement: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler<LockedAccount>;
    }){

        public func add_deposit({
            deposits: Map.Map<Nat, LockedDeposit>;
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {

            // Ensure the timestamp of is greater than the timestamp of the last lock
            // @todo: this should be done in the lock scheduler, but because we call an await before
            // the scheduler we do it here
            Option.iterate(Map.peek(deposits), func((_, lock): (Nat, LockedDeposit)) {
                if (lock.timestamp > timestamp) {
                    Debug.trap("The timestamp of the last lock is greater than given timestamp");
                };
            });

            // Perform the deposit
            let deposit_result = await* payement.add_deposit({ caller; from = account; amount; time = timestamp; });

            // Add the lock if the deposit was successful
            Result.iterate(deposit_result, func(tx_index: Nat){
                lock_scheduler.new_lock({ locks = deposits; id = tx_index; amount; timestamp; data = { account; } });
            });

            deposit_result;
        };

        public func try_refund(deposits: Map.Map<Nat, LockedDeposit>, time: Time) : Buffer<TransferCallback> {

            // For each deposit unlocked, prepare the refund (do not execute it yet)
            Buffer.map<LockedDeposit, TransferCallback>(lock_scheduler.try_unlock(deposits, time), func(deposit: LockedDeposit) : TransferCallback {
                func() : async* TransferResult {
                    await* payement.refund_deposit({
                        origin_account = deposit.data.account;
                        amount = deposit.amount;
                        time; 
                    });
                };
            });
        };

    };
}