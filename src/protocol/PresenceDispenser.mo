import Types "Types";
import DebtProcessor "DebtProcessor";

import BTree "mo:stableheapbtreemap/BTree";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {

    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Time = Int;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;

    type PresenseParameters = Types.PresenseParameters;

    // Required just amount and from fields from YesNoBallot
    public class PresenceDispenser({
        locks: BTree<Lock, YesNoBallot>;
        parameters: PresenseParameters;
        debt_processor: DebtProcessor.DebtProcessor;
    }) {

        // @todo: map fold
        func get_total_locked() : Nat {
            var total : Nat = 0;
            for ((_, ballot) in BTree.entries(locks)) {
                total += ballot.amount;
            };
            total;
        };

        var total_locked = get_total_locked();

        public func about_to_add(ballot: YesNoBallot, time: Time) {
            dispense(time);
            total_locked += ballot.amount;
        };

        public func about_to_remove(ballot: YesNoBallot, time: Time) {
            dispense(time);
            total_locked -= ballot.amount;
        };

        public func dispense(time: Time) {
            
            let period = Float.fromInt(time - parameters.time_last_dispense);

            if (period < 0) {
                Debug.trap("Cannot dispense presence in the past");
            };

            // Dispense presence over the period
            label dispense for (({id}, ballot) in BTree.entries(locks)) {
                
                // Add to the debt
                debt_processor.add_debt({
                    id;
                    account = ballot.from;
                    amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * parameters.presence_per_ns * period;
                    time;
                });
            };

            // Update the time of the last dispense
            parameters.time_last_dispense := time;
        };
        
    };
};