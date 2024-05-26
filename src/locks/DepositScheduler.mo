import LockScheduler "LockScheduler";
import Types "../Types";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

module {

    type Account = Types.Account;
    public type LockInfo = LockScheduler.LockInfo;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;

    type Time = Int;
    type AddDepositResult = Result<Nat, PayementFacade.AddDepositError>; // ID

    public type DepositInfo = {
        tx_id: Nat;
        account: Account;
        amount: Nat;
        timestamp: Time;
        state: DepositState;
    };

    type DepositState = Types.DepositState;

    public class DepositScheduler<T>({
        payement_facade: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler<T>;
        update_deposit: (T, DepositInfo) -> T;
        get_deposit: (T) -> DepositInfo;
    }){

        public func add_deposit({
            map: Map<Nat, T>;
            add_new: (DepositInfo, LockInfo) -> (Nat, T);
            caller: Principal;
            account: Account;   
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {

            // Perform the deposit
            let deposit_result = await* payement_facade.add_deposit({ caller; from = account; amount; time = timestamp; });

            // Add the lock if the deposit was successful
            Result.mapOk(deposit_result, func(tx_id: Nat) : Nat {

                // Callback to add the element to the map
                func new(lock_info: LockInfo) : (Nat, T) {
                    let deposit_info = {
                        tx_id;
                        account;
                        amount;
                        timestamp;
                        state = to_deposit_state(lock_info.state);
                    };
                    add_new(deposit_info, lock_info);
                };

                // Add the lock
                lock_scheduler.new_lock({ map; new; amount; timestamp; });
            });
        };

        public func try_refund({
            map: Map<Nat, T>;
            time: Time;
        }) : async* [Nat] {

            let unlocked = lock_scheduler.try_unlock(map, time);

            for((id, elem) in unlocked.vals()) {

                let deposit = get_deposit(elem);

                let refund_fct = func() : async* () {

                    // Perform the refund
                    let refund_result = await* payement_facade.refund_deposit({
                        amount = deposit.amount;
                        origin_account = deposit.account;
                        time; 
                    });

                    // Update the deposit state
                    let transfer = switch(refund_result){
                        case(#ok(tx_id)) { #SUCCESS({tx_id;}); };
                        case(#err(_)) { #FAILED; };
                    };
                    Map.set(map, Map.nhash, id, update_deposit(elem, { deposit with state =  #UNLOCKED({since = time; transfer; }) }));
                };

                // Trigger the refund and callback, but do not wait for them to complete
                ignore refund_fct();
            };

            Buffer.toArray(Buffer.map<(Nat, T), Nat>(unlocked, func((id, elem): (Nat, T)) : Nat { id; }));
        };

        func to_deposit_state(lock_state: LockScheduler.LockState) : DepositState {
            switch(lock_state) {
                case(#LOCKED{until}) { #LOCKED{until}; };
                case(#UNLOCKED{since}) { #UNLOCKED{since; transfer = #PENDING; }; };
            };
        };

    };
}