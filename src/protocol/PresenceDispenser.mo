import Types "Types";
import DebtProcessor "DebtProcessor";
import Timeline "utils/Timeline";

import BTree "mo:stableheapbtreemap/BTree";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {

    type Time = Int;
    type LockRegister = Types.LockRegister;
    type PresenseParameters = Types.PresenseParameters;
    type PresenceInfo = Types.PresenceInfo;

    public class PresenceDispenser({
        lock_register: LockRegister;
        parameters: PresenseParameters;
        debt_processor: DebtProcessor.DebtProcessor;
    }) {

        public func dispense(time: Time) {
            
            let period = Float.fromInt(time - parameters.time_last_dispense);

            if (period < 0) {
                Debug.trap("Cannot dispense presence in the past");
            };

            Debug.print("Dispensing presence over period: " # debug_show(period));

            let total_amount = Timeline.current(lock_register.total_amount);

            // Dispense presence over the period
            label dispense for (({id}, ballot) in BTree.entries(lock_register.locks)) {
                
                // Add to the debt
                debt_processor.add_debt({
                    id;
                    amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_amount)) * parameters.presence_per_ns * period;
                    time;
                });
            };

            // Update the time of the last dispense
            parameters.time_last_dispense := time;
        };

        public func get_info() : PresenceInfo {
            {
                presence_per_ns = parameters.presence_per_ns;
                time_last_dispense = parameters.time_last_dispense;
                ck_btc_locked = lock_register.total_amount;
            };
        };
        
    };
};