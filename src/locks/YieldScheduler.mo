import DepositScheduler "DepositScheduler";
import Types "../Types";
import PayementFacade "../PayementFacade";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

    type Account = Types.Account;
    public type LockInfo = DepositScheduler.LockInfo;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<T, E> = Result.Result<T, E>;

    type Time = Int;
    type AddDepositResult = Result<Nat, PayementFacade.AddDepositError>; // ID

    public type DepositInfo = DepositScheduler.DepositInfo;
    public type DepositState = Types.DepositState;

    type YieldState = Types.YieldState;
    public type YieldInfo = {
        account: Account;
        state: YieldState;
    };

    public class YieldScheduler<T>({
        payement: PayementFacade.PayementFacade;
        deposit_scheduler: DepositScheduler.DepositScheduler<T>;
        get_yield: (T) -> YieldInfo;
        update_yield: (T, YieldInfo) -> T;
    }){

        public func add_deposit({
            map: Map<Nat, T>;
            add_new: (DepositInfo, LockInfo) -> (Nat, T);
            caller: Principal;
            account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {
            await* deposit_scheduler.add_deposit(
                { map; add_new; caller; account; amount; timestamp; });
        };

        public func try_refund_and_reward({
            map: Map<Nat, T>;
            reward_amount: T -> Nat;
            time: Time;
        }) : async* [Nat] {

            let refunds = await* deposit_scheduler.try_refund(map, time);
            label rewards for (id in Array.vals(refunds)) {
                let elem = switch(Map.get(map, Map.nhash, id)){
                    case(null) { Debug.print("Element " #  debug_show(id) # " not found"); continue rewards; };
                    case(?elem) { elem; };
                };

                let amount = reward_amount(elem);
                let yield = get_yield(elem);

                // Mark the reward as pending
                Map.set(map, Map.nhash, id, update_yield(elem, { yield with state = #PENDING_TRANSFER({since = time; amount;}) }));

                let reward_fct = func() : async* () {

                    // Perform the reward
                    let reward_result = await* payement.grant_reward({
                        amount;
                        to = yield.account;
                        time; 
                    });

                    // Update the yield state
                    let state = switch(reward_result){
                        case(#ok(tx_id)) { #TRANSFERRED({tx_id;}); };
                        case(#err(_)) { #FAILED_TRANSFER; };
                    };
                    Map.set(map, Map.nhash, id, update_yield(elem, { yield with state; }));
                };

                // Trigger the reward and callback, but do not wait for them to complete
                ignore reward_fct();
            };
            refunds
        };

    };
}