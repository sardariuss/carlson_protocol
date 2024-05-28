import LockScheduler "LockScheduler";
import Types "../Types";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

module {

    type Account = Types.Account;
    public type LockInfo = LockScheduler.LockInfo;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;

    type Time = Int;
    type PayServiceResult = PayementFacade.PayServiceResult;

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
            from: Account;   
            amount: Nat;
            timestamp: Time;
        }) : async* PayServiceResult {

            func create_deposit(tx_id: Nat) : async* Nat {

                // Callback to add the element to the map
                func new(lock_info: LockInfo) : (Nat, T) {
                    let deposit_info = {
                        tx_id;
                        account = from;
                        amount;
                        timestamp;
                        state = to_deposit_state(lock_info.state);
                    };
                    add_new(deposit_info, lock_info);
                };

                // Add the lock
                lock_scheduler.new_lock({ map; new; amount; timestamp; });
            };

            // Perform the deposit
            await* payement_facade.pay_service({ 
                caller;
                from;
                amount;
                time = timestamp;
                to_subaccount = ?Principal.toBlob(caller); // @todo: create unique deposit account
                service = create_deposit;
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
                    let refund_result = await* payement_facade.send_payement({
                        amount = deposit.amount;
                        to = deposit.account;
                        from_subaccount = ?Principal.toBlob(deposit.account.owner); // @todo: use saved deposit account
                        time; 
                    });

                    // Update the deposit state
                    let transfer = switch(refund_result){
                        case(#ok(tx_id)) { #SUCCESS({tx_id;}); };
                        case(#err({incident_id})) { #FAILED{incident_id}; };
                    };
                    Map.set(map, Map.nhash, id, update_deposit(elem, { deposit with state = #UNLOCKED({ since = time; transfer; }) }));
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