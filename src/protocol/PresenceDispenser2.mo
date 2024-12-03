import Types "Types";
import DebtProcessor "DebtProcessor";
import LockScheduler2 "LockScheduler2";

import BTree "mo:stableheapbtreemap/BTree";
import Map "mo:map/Map";
import Option "mo:base/Option";
import Float "mo:base/Float";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Map<K, V> = Map.Map<K, V>;
    type Time = Int;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;

    type PresenseParameters = Types.PresenseParameters;

    public class PresenceDispenser2({
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

        public func handle_lock_added(lock: Lock, ballot: YesNoBallot) {

            dispense(ballot.timestamp, ?lock, null);

            // Update the total amount locked
            total_locked += ballot.amount;
        };

        public func handle_lock_removed(_: Lock, ballot: YesNoBallot) {

            dispense(ballot.timestamp + ballot.duration_ns.current.data, null, ?ballot);

            // Update the total amount locked
            total_locked -= ballot.amount;
        };

        public func dispense(time: Time, skip_lock: ?Lock, extra_ballot: ?YesNoBallot) {
            
            let period = Float.fromInt(time - parameters.time_last_dispense);

            // Dispense presence over the period
            label dispense for (({id}, ballot) in BTree.entries(locks)) {
                
                // Do not consider the lock to skip
                switch(skip_lock) {
                    case(null) {};
                    case(?lock) {
                        if (id == lock.id) {
                            continue dispense;
                        };
                    };
                };
                
                // Add to the debt
                add_presence_debt({id; ballot; period; time; });
            };
            switch(extra_ballot) {
                case(null) {};
                case(?ballot) {
                    // Add to the debt
                    add_presence_debt({id = ""; ballot; period; time; }); // @TODO!
                };
            };

            // Update the time of the last dispense
            parameters.time_last_dispense := time;
        };

        func add_presence_debt({ id: UUID; ballot: YesNoBallot; period: Float; time: Time; }) {
            debt_processor.add_debt({
                id;
                account = ballot.from;
                amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * parameters.presence_per_ns * period;
                time;
            });
        };
        
    };
};