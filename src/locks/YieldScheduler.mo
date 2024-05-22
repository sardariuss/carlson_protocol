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
    type YieldInfo = {
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
            add_new2: (DepositInfo, LockInfo, YieldInfo) -> (Nat, T);
            caller: Principal;
            deposit_account: Account;   
            reward_account: Account;
            amount: Nat;
            timestamp: Time;
        }) : async* AddDepositResult {
            await* deposit_scheduler.add_deposit(
                { map; add_new = func (deposit_info: DepositInfo, lock_info: LockInfo) : (Nat, T) {
                    let yield_info = { account = reward_account; state = #PENDING; };
                    add_new2(deposit_info, lock_info, yield_info);
                }; caller; account = deposit_account; amount; timestamp; });
        };

        public func try_refund_and_reward(
            map: Map<Nat, T>,
            reward_amount: T -> Nat,
            time: Time,
        ) : async* [Nat] {

            let refunds = await* deposit_scheduler.try_refund(map, time);
            for (id in Array.vals(refunds)) {
                let elem = switch(Map.get(map, Map.nhash, id)){
                    case(null) { Debug.trap("@todo: Element not found"); };
                    case(?elem) { elem; };
                };

                let amount = reward_amount(elem);
                let yield = get_yield(elem);

                // Mark the reward as pending
                Map.set(map, Map.nhash, id, update_yield(elem, { yield with state = #PENDING_REFUND({since = time; amount;}) }));

                let reward_fct = func() : async* () {

                    // Perform the reward
                    let reward_result = await* payement.grant_reward({
                        amount;
                        to = yield.account;
                        time; 
                    });

                    // Update the yield state
                    let state = switch(reward_result){
                        case(#ok(tx_id)) { #REFUNDED({tx_id;}); };
                        case(#err(_)) { #FAILED_REFUND; };
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