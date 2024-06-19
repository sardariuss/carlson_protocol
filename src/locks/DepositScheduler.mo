import LockScheduler    "LockScheduler";
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
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;

    type Time = Int;
    type PayServiceResult = PayementFacade.PayServiceResult;
    type RefundState = Types.RefundState;

    type IDepositInfoBuilder<T> = LockScheduler.ILockInfoBuilder<T> and {
        add_deposit: ({ tx_id: Nat; from: Account; subaccount: Blob; }) -> ();
    };

    public type DepositInfo = {
        tx_id: Nat;
        from: Account;
        subaccount: Blob;
        amount: Nat;
        timestamp: Time;
    };

    public type AddDepositArgs = {
        caller: Principal;
        from: Account;
        time: Time;
        amount: Nat;
    };

    type DepositState = Types.DepositState;

    public class DepositScheduler<T>({
        subaccount_indexer: SubaccountIndexer.SubaccountIndexer;
        payement_facade: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler<T>;
        tag_refunded: (T, RefundState) -> T;
        get_deposit: (T) -> DepositInfo;
    }){

        public func add_deposit({
            register: LockScheduler.LockRegister<T>;
            builder: IDepositInfoBuilder<T>;
            callback: T -> ();
            args: AddDepositArgs;
        }) : async* PayServiceResult {

            let { from; time; amount; } = args;
            let subaccount = subaccount_indexer.new_deposit_subaccount();

            // Define the service to be called once the payement is done
            func service(tx_id: Nat) : async* Nat {
                // Add the deposit inside the element itself
                builder.add_deposit({ tx_id; from; subaccount; });
                // Add the lock for that deposit in the scheduler
                let (id, deposit) = lock_scheduler.add_lock({ register; builder; amount; timestamp = time; });
                // Perform the callback
                callback(deposit);
                // Return the deposit id
                id;
            };

            // Perform the deposit
            await* payement_facade.pay_service({ args and { to_subaccount = ?subaccount; service; } });
        };

        public func try_refund({
            register: LockScheduler.LockRegister<T>;
            time: Time;
        }) : async* [Nat] {

            let unlocked = lock_scheduler.try_unlock({register; time; });

            // For each unlocked deposit, refund the locked amount to the sender
            for((id, elem) in unlocked.vals()) {

                let deposit = get_deposit(elem);

                let refund_fct = func() : async* () {

                    // Perform the refund
                    let refund_result = await* payement_facade.send_payement({
                        amount = deposit.amount;
                        to = deposit.from;
                        from_subaccount = ?deposit.subaccount;
                        time; 
                    });

                    // Update the deposit state
                    let transfer = switch(refund_result){
                        case(#ok(tx_id)) { #SUCCESS({tx_id;}); };
                        case(#err({incident_id})) { #FAILED{incident_id}; };
                    };
                    Map.set(register.map, Map.nhash, id, tag_refunded(elem, { transfer; since = time; }));
                };

                // Trigger the refund but do not wait for them to complete
                ignore refund_fct();
            };

            Buffer.toArray(Buffer.map<(Nat, T), Nat>(unlocked, func((id, elem): (Nat, T)) : Nat { id; }));
        };

    };
}