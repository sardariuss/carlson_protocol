import Types            "../Types";
import LockScheduler    "../locks/LockScheduler";
import PayementFacade   "PayementFacade";

import Map              "mo:map/Map";

import Result           "mo:base/Result";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";

module {

    type Account = Types.Account;
    type Buffer<T> = Buffer.Buffer<T>;
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Time = Int;
    type AddDepositResult = PayementFacade.PayServiceResult;
    type RefundState = Types.RefundState;
    type DepositInfo = Types.DepositInfo;

    type IDepositInfoBuilder<T> = LockScheduler.ILockInfoBuilder<T> and {
        add_deposit: (DepositInfo) -> ();
    };

    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;

    public type Deposit = {
        tx_id: Nat;
        from: Account;
        amount: Nat;
        timestamp: Time;
    };

    public type AddDepositArgs = {
        from: Account;
        time: Time;
        amount: Nat;
    };

    type DepositState = Types.DepositState;

    // @todo: why pass register in every function?
    public class DepositScheduler<T>({
        deposit_facade: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler<T>;
        tag_refunded: (T, RefundState) -> T;
        get_deposit: (T) -> Deposit;
    }){

        public func preview_deposit({
            register: LockScheduler.LockRegister<T>;
            builder: IDepositInfoBuilder<T>;
            args: AddDepositArgs;
        }) : T {
            let { from; time; amount; } = args;

            // @todo
            builder.add_deposit({ tx_id = 0; from; deposit_state = #DEPOSITED; });
            
            lock_scheduler.preview_lock({ register; builder; amount; timestamp = time; });
        };

        public func add_deposit({
            register: LockScheduler.LockRegister<T>;
            builder: IDepositInfoBuilder<T>;
            callback: (T) -> ();
            args: AddDepositArgs;
        }) : async* AddDepositResult {

            let { from; time; amount; } = args;

            // Define the service to be called once the payement is done
            func service({tx_id: Nat}) : async* Result<Nat, Text> {
                // Set the deposit information inside the element itself
                builder.add_deposit({ tx_id; from; deposit_state = #DEPOSITED; });
                // Add the lock for that deposit in the scheduler
                switch(lock_scheduler.add_lock({ register; builder; amount; timestamp = time; })){
                    case(#ok((id, deposit))) { callback(deposit); #ok(id); };
                    case(#err(err)){ #err(err); };
                };
            };

            // Perform the deposit
            await* deposit_facade.pay_service({ args and { service; } });
        };

        public func attempt_release({
            register: LockScheduler.LockRegister<T>;
            time: Time;
            on_release_attempt: (ReleaseAttempt<T>) -> ();
        }) : async* () {

            let release_attempts = lock_scheduler.attempt_release({ register; time; });

            for((id, attempt) in release_attempts.vals()) {

                on_release_attempt(attempt);

                // If the attempt was successful, refund the deposit
                switch(attempt.release_time){
                    case(?since){

                        let deposit = get_deposit(attempt.elem);

                        let refund_fct = func() : async() {

                            // Perform the refund
                            let refund_result = await* deposit_facade.send_payement({
                                amount = deposit.amount;
                                to = deposit.from;
                            });

                            // Update the deposit state
                            let transfer = switch(refund_result){
                                case(#ok(tx_id)) { #SUCCESS({tx_id;}); };
                                case(#err({incident_id})) { #FAILED{incident_id}; };
                            };
                            // @todo: this does not seem to work
                            Map.set(register.map, Map.nhash, id, tag_refunded(attempt.elem, { transfer; since; }));
                        };

                        // Trigger the refund but do not wait for it to complete
                        ignore refund_fct();
                    };
                    case(null) {};
                };

            };
        };

    };
}