import Types          "../Types";
import PayementFacade "../payement/PayementFacade";

module {

    type Time = Int;
    type Account = Types.Account;
    type RewardState = Types.RewardState;
    
    public type RewardInfo = {
        account: Account;
        state: RewardState;
    };

    public class RewardScheduler<T>({
        reward_facade: PayementFacade.PayementFacade;
        get_reward: (T) -> RewardInfo;
        update_reward: (T, RewardInfo) -> T;
    }){

        public func send_reward({
            to: T;
            amount: Nat;
            time: Time;
            update_elem: (T) -> ();
        }) : async* () {

            let reward = get_reward(to);

            update_elem(update_reward(to, { reward with state = #PENDING_TRANSFER({since = time; amount;}) }));

            let reward_fct = func() : async* () {

                // Perform the reward
                let reward_result = await* reward_facade.send_payement({
                    amount;
                    to = reward.account;
                    from_subaccount = null;
                    time; 
                });

                // Update the reward state
                let state = switch(reward_result){
                    case(#ok(tx_id)) { #TRANSFERRED({tx_id;}); };
                    case(#err({incident_id})) { #FAILED_TRANSFER{incident_id}; };
                };

                update_elem(update_reward(to, { reward with state; }));
            };

            // Trigger the reward and callback, but do not wait for them to complete
            ignore reward_fct();
        };

    };
}