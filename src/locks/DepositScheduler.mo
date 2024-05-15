import LockScheduler "LockScheduler";
import Types "../Types";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Option "mo:base/Option";
import Debug  "mo:base/Debug";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";

module {

    type Account = Types.Account;
    type Lock = LockScheduler.Lock;
    type Buffer<T> = Buffer.Buffer<T>;

    type Time = Int;
    type AddDepositResult = PayementFacade.AddDepositResult;

    public type Register = {
        id: Nat;
        deposits: Map.Map<Nat, Deposit>;
        locks: Map.Map<Nat, Lock>;
    };

    public func new_register(id: Nat) : Register {
        { id; deposits = Map.new(); locks = Map.new(); };
    };

    type Deposit = {
        account: Account;
        amount: Nat;
        timestamp: Time;
        state: DepositState;
    };

    type DepositState = {
        #LOCKED;
        #PENDING_REFUND: { time: Time };
        #FAILED_REFUND: { error: PayementFacade.TransferError };
        #REFUNDED: { tx_index: Nat };
    };

    public class DepositScheduler({
        payement: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler;
    }){

        public func add_deposit({
            register: Register;
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {

            // Ensure the timestamp of is greater than the timestamp of the last lock
            // @todo: this should be done in the lock scheduler, but because we call an await before
            // the scheduler we do it here
            Option.iterate(Map.peek(register.locks), func((_, lock): (Nat, Lock)) {
                if (lock.timestamp > timestamp) {
                    Debug.trap("The timestamp of the last lock is greater than given timestamp");
                };
            });

            // Perform the deposit
            let deposit_result = await* payement.add_deposit({ caller; from = account; amount; time = timestamp; });

            // Add the lock if the deposit was successful
            Result.iterate(deposit_result, func(tx_index: Nat){
                Map.set(register.deposits, Map.nhash, tx_index, { account; amount; timestamp; state = #LOCKED; });
                lock_scheduler.new_lock({ locks = register.locks; id = tx_index; amount; timestamp; data = { account; } });
            });

            deposit_result;
        };

        public func try_refund(
            register: Register,
            time: Time,
        ) : async* [Nat] {

            let unlocked = lock_scheduler.try_unlock(register.locks, time);

            for(lock in unlocked.vals()) {

                // Get the deposit
                let deposit = switch(Map.get(register.deposits, Map.nhash, lock.id)) {
                    case(?d) { d; };
                    case(null) { 
                        // This case shall never happen, for every lock added a deposit is added
                        Debug.trap("Deposit with id=" # debug_show(lock.id) # " not found in register with id" # debug_show(register.id));
                    };
                };

                // Mark the refund as pending
                Map.set(register.deposits, Map.nhash, lock.id, { deposit with state = #PENDING_REFUND({time}); });

                let refund_fct = func() : async* () {

                    // Perform the refund
                    let refund_result = await* payement.refund_deposit({
                        amount = deposit.amount;
                        origin_account = deposit.account;
                        time; 
                    });

                    // Update the deposit state
                    let state = switch(refund_result){
                        case(#ok(tx_index)) { #REFUNDED({tx_index;}); };
                        case(#err(error)) { #FAILED_REFUND({error;}); };
                    };
                    Map.set(register.deposits, Map.nhash, lock.id, { deposit with state; });
                };

                // Trigger the refund
                ignore refund_fct();
            };

            Buffer.toArray(Buffer.map<Lock, Nat>(unlocked, func(lock: Lock) : Nat { lock.id; }));
        };

    };
}