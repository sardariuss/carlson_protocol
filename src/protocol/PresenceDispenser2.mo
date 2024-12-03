import Types "Types";
import DebtProcessor "DebtProcessor";

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
        locks: BTree<Lock, ()>;
        ballots: Map<UUID, YesNoBallot>;
        parameters: PresenseParameters;
        debt_processor: DebtProcessor.DebtProcessor;
    }) {

        // @todo: map fold
        func get_total_locked() : Nat {
            var total : Nat = 0;
            for ((_, ballot) in Map.entries(ballots)) {
                total += ballot.amount;
            };
            total;
        };

        var total_locked = get_total_locked();

        public func handle_lock_added(lock: Lock, time: Time) {

            dispense(time, ?lock, null);

            // Update the total amount locked
            Option.iterate(Map.get(ballots, Map.thash, lock.ref), func(ballot: YesNoBallot) { total_locked += ballot.amount; });
        };

        public func handle_lock_removed(lock: Lock, time: Time) {

            dispense(time, null, ?lock);

            // Update the total amount locked
            Option.iterate(Map.get(ballots, Map.thash, lock.ref), func(ballot: YesNoBallot) { total_locked -= ballot.amount; });
        };

        public func dispense(time: Time, skip_lock: ?Lock, extra_lock: ?Lock) {
            
            let period = Float.fromInt(time - parameters.time_last_dispense);

            // Dispense presence over the period
            label dispense for (({ref}, _) in BTree.entries(locks)) {
                
                // Do not consider the lock to skip
                switch(skip_lock) {
                    case(null) {};
                    case(?lock) {
                        if (ref == lock.ref) {
                            continue dispense;
                        };
                    };
                };
                
                // Add to the debt
                add_presence_debt({id = ref; period; time; });
            };
            switch(extra_lock) {
                case(null) {};
                case(?lock) {
                    // Add to the debt
                    add_presence_debt({id = lock.ref; period; time; });
                };
            };

            // Update the time of the last dispense
            parameters.time_last_dispense := time;
        };

        func add_presence_debt({ id: UUID; period: Float; time: Time; }) {
            Option.iterate(Map.get(ballots, Map.thash, id), func(ballot: YesNoBallot) {
                debt_processor.add_debt({
                    id;
                    account = ballot.from;
                    amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * parameters.presence_per_ns * period;
                    time;
                });
            });
        };
        
    };
};