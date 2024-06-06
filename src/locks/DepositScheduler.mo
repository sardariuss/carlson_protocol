import LockScheduler    "LockScheduler";
import HotMap           "HotMap";
import Types             "../Types";
import PayementFacade    "../payement/PayementFacade";
import SubaccountIndexer "../payement/SubaccountIndexer";

import Map              "mo:map/Map";

import Result           "mo:base/Result";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";
import Principal        "mo:base/Principal";

module {

    type Account = Types.Account;
    public type HotInfo = HotMap.HotInfo;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;

    type Time = Int;
    type PayServiceResult = PayementFacade.PayServiceResult;
    type RefundState = Types.RefundState;

    public type SliceInfo = {
        from: Account;
        amount: Nat;
        timestamp: Time;
    };

    public type DepositInfo = {
        deposit_state: DepositState;
        subaccount: Blob; 
        tx_id: Nat;
    };

    type DepositState = Types.DepositState;

    type Composite<S> = { slice: S } and DepositInfo;

    public class DepositScheduler<V, S>({
        subaccount_indexer: SubaccountIndexer.SubaccountIndexer;
        payement_facade: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler<V, Composite<S>>;
        to_composite: V -> Composite<S>;
        update_value: (V, DepositInfo) -> V;
        get_info: S -> SliceInfo;
    }){

        public func add_deposit({
            register: LockScheduler.LockRegister<V>;
            caller: Principal;
            elem: S;
            callback: () -> ();
        }) : async* PayServiceResult {

            let { from; amount; timestamp; } = get_info(elem);
            let subaccount = subaccount_indexer.new_deposit_subaccount();

            func service(tx_id: Nat) : async* Nat {
                // Execute the callback
                callback();
                // Add the lock
                lock_scheduler.add_lock({ register; lock = { slice = elem; subaccount; tx_id; deposit_state = #LOCKED{ until = 0; }}; }).0; // @todo
            };

            // Perform the deposit
            await* payement_facade.pay_service({ 
                caller;
                from;
                amount;
                time = timestamp;
                to_subaccount = ?subaccount;
                service;
            });
        };

        public func try_refund({
            register: LockScheduler.LockRegister<V>;
            time: Time;
        }) : async* [Nat] {

            let unlocked = lock_scheduler.try_unlock({ register; time; });

            // For each unlocked deposit, refund the locked amount to the sender
            for((id, elem) in unlocked.vals()) {

                let deposit = to_composite(elem);
                let { from; amount; } = get_info(deposit.slice);

                let refund_fct = func() : async* () {

                    // Perform the refund
                    let refund_result = await* payement_facade.send_payement({
                        amount;
                        to = from;
                        from_subaccount = ?deposit.subaccount;
                        time; 
                    });

                    // Update the deposit state
                    let transfer = switch(refund_result){
                        case(#ok(tx_id)) { #SUCCESS({tx_id;}); };
                        case(#err({incident_id})) { #FAILED{incident_id}; };
                    };
                    Map.set(register.map, Map.nhash, id, update_value(elem, { deposit with deposit_state = #REFUNDED({ transfer; since = time; }) }));
                };

                // Trigger the refund but do not wait for them to complete
                ignore refund_fct();
            };

            Buffer.toArray(Buffer.map<(Nat, V), Nat>(unlocked, func((id, elem): (Nat, V)) : Nat { id; }));
        };

    };
}