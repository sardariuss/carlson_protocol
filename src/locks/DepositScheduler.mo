import LockScheduler "LockScheduler2";
import Types "../Types";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Option "mo:base/Option";
import Debug  "mo:base/Debug";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

module {

    type Account = Types.Account;
    type Lock = LockScheduler.Lock;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;

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
        tx_index: Nat;
        account: Account;
        amount: Nat;
        timestamp: Time;
        decay: Float;
        hotness: Float;
        state: DepositState;
    };

    type DepositState = Types.DepositState;

    public class DepositScheduler({
        payement: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler;
    }){

        public func add_deposit({
            iter: Iter<(Nat, Deposit)>;
            update: (Nat, Deposit) -> ();
            add: Deposit -> Nat;
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {

            // Perform the deposit
            let deposit_result = await* payement.add_deposit({ caller; from = account; amount; time = timestamp; });

            // Add the lock if the deposit was successful
            Result.mapOk(deposit_result, func(tx_index: Nat){
                lock_scheduler.new_lock({
                    iter = to_lock_iter(iter);
                    update = to_lock_update(update);
                    add = to_lock_add(add, tx_index, account);
                    amount;
                    timestamp;
                });
            });
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

        func to_lock_iter(deposit_iter: Iter<(Nat, Deposit)>) : Iter<(Nat, Lock)> {
            func next() : ?(Nat, Lock) {
                for ((id, deposit) in deposit_iter){
                    switch(deposit.state){
                        case(#LOCKED({expiration})){
                            return ?(id, { deposit with expiration });
                        };
                        case(_) {};
                    };
                };
                null;
            };
            { next; }
        };
        
        func to_lock_update(deposit_update: (Nat, Deposit) -> ()) : (Nat, Lock) -> () {
             
        };
        
        func to_lock_add(deposit_add: Deposit -> Nat) : Lock -> Nat {

        };
        

    };
}