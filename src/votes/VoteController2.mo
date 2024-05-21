import Types          "../Types";
import PayementFacade "../PayementFacade";
import LockScheduler  "../locks/LockScheduler2";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import VotePolicy     "VotePolicy";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";
import Result         "mo:base/Result";
import Option         "mo:base/Option";

module {

    type Time = Int;

    public type VoteId = Nat;

    type DepositError = PayementFacade.DepositError;
    type Account = Types.Account;
    type Lock = LockScheduler.Lock;
    type Iter<T> = Iter.Iter<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Vote<A, B> = {
        author: Principal;
        tx_id: Nat;
        date: Time;
        var aggregate: A;
        ballot_register: {
            var index: Nat;
            ballots: Map.Map<Nat, Ballot<B>>;
        };
    };

    type Ballot<B> = {
        tx_id: Nat;
        from: Account;
        date: Time;
        hotness: Float;
        decay: Float;
        deposit_state: DepositState;
        contest: Float;
        choice: B;
    };

    type DepositState = {
        #LOCKED: {expiration: Time};
        #PENDING_REFUND: {since: Time};
        #OWED: {id: Nat};
        #REFUNDED: {tx_id: Nat};
    };


    type UpdatePolicy<A, B> = VotePolicy.UpdatePolicy<A, B>;
   
    public class VoteController<A, B>({
        vote: Vote<A, B>;
        ballot_amount: B -> Nat;
        add_to_aggregate: UpdatePolicy<A, B>;
        compute_contest: (A, B, Time) -> Float;
        payement: PayementFacade.PayementFacade;
        lock_scheduler: LockScheduler.LockScheduler;
    }){

        // Vote (by adding the given ballot)
        // Trap if the vote does not exist or if the ballot has already been added
        public func put_ballot({
            caller: Principal;
            from: Account;
            date: Time;
            choice: B;
        }) : async* Result<Nat, DepositError> {

            let amount = ballot_amount(choice);

            // Perform the deposit
            let deposit_result = await* payement.add_deposit({ caller; from; amount; time = date; });

            Result.mapOk(deposit_result, func(tx_id: Nat) : Nat {
                
                // Add the ballot
                let ballot_id = lock_scheduler.new_lock({
                    iter = iter_locked_ballots();
                    update = update_ballot;
                    add = add_ballot({tx_id; date; from; choice; current_aggregate = vote.aggregate});
                    amount;
                    timestamp = date;
                });

                // Update the aggregate
                vote.aggregate := add_to_aggregate({aggregate = vote.aggregate; ballot = choice;});

                ballot_id;
            });
        };

        func iter_locked_ballots() : Iter<(Nat, Lock)> {
            var iter = Map.entries(vote.ballot_register.ballots);
            func next() : ?(Nat, Lock) {
                for ((id, ballot) in iter){
                    switch(ballot.deposit_state){
                        case(#LOCKED({expiration})){
                            return ?(
                                id, 
                                {
                                    amount = ballot_amount(ballot.choice);
                                    timestamp = ballot.date;
                                    decay = ballot.decay;
                                    hotness = ballot.hotness;
                                    expiration = expiration;
                                }
                            );
                        };
                        case(_) {};
                    };
                };
                null;
            };
            { next; }
        };

        func update_ballot(id: Nat, lock: Lock) {
            let updated_ballot = switch(Map.get(vote.ballot_register.ballots, Map.nhash, id)) {
                case(null) { Debug.trap("Ballot not found"); }; // @todo
                case(?b) { 
                    { 
                        b with 
                        decay = lock.decay;
                        hotness = lock.hotness;
                        deposit_state = #LOCKED({expiration = lock.expiration});
                    } 
                };
            };

            Map.set(vote.ballot_register.ballots, Map.nhash, id, updated_ballot);
        };

        func add_ballot({
            tx_id: Nat;
            date: Time;
            from: Account;
            choice: B;
            current_aggregate: A;
        }) : (Lock) -> Nat {

            func(lock: Lock) : Nat {
                // Get the next ballot id
                let ballot_id = vote.ballot_register.index;
                vote.ballot_register.index := vote.ballot_register.index + 1;

                // Add the ballot
                Map.set(vote.ballot_register.ballots, Map.nhash, ballot_id, {
                    tx_id;
                    from;
                    date;
                    hotness = lock.hotness;
                    decay = lock.decay;
                    deposit_state = #LOCKED({expiration = lock.expiration});
                    contest = compute_contest(current_aggregate, choice, date);
                    choice;
                });

                // Return the ballot id
                ballot_id;
            };
        };
    };

};