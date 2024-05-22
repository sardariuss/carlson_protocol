import Types          "../Types";
import PayementFacade "../PayementFacade";
import DepositScheduler  "../locks/DepositScheduler";

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

    type AddDepositError = PayementFacade.AddDepositError;
    type Account = Types.Account;
    type Iter<T> = Iter.Iter<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    type UpdatePolicy<A, B> = VotePolicy.UpdatePolicy<A, B>;
   
    public class VoteController<A, B>({
        vote: Vote<A, B>;
        ballot_amount: B -> Nat;
        add_to_aggregate: UpdatePolicy<A, B>;
        compute_contest: (A, B, Time) -> Float;
        payement: PayementFacade.PayementFacade;
        deposit_scheduler: DepositScheduler.DepositScheduler<Ballot<B>>;
    }){

        // Vote (by adding the given ballot)
        // Trap if the vote does not exist or if the ballot has already been added
        public func put_ballot({
            caller: Principal;
            from: Account;
            date: Time;
            choice: B;
        }) : async* Result<Nat, AddDepositError> {

            func add_new(deposit_info: DepositScheduler.DepositInfo, lock_info: DepositScheduler.LockInfo) : (Nat, Ballot<B>){

                // Update the aggregate
                vote.aggregate := add_to_aggregate({aggregate = vote.aggregate; ballot = choice;});

                // Get the next ballot id
                let ballot_id = vote.ballot_register.index;
                vote.ballot_register.index := vote.ballot_register.index + 1;

                // Add the ballot
                let ballot = {
                    tx_id = deposit_info.tx_id;
                    from;
                    date;
                    hotness = lock_info.hotness;
                    decay = lock_info.decay;
                    deposit_state = deposit_info.state;
                    contest = compute_contest(vote.aggregate, choice, date);
                    choice;
                };
                Map.set(vote.ballot_register.ballots, Map.nhash, ballot_id, ballot);

                // Return the id and the ballot
                (ballot_id, ballot);
            };

            // Perform the deposit
            await* deposit_scheduler.add_deposit({
                map = vote.ballot_register.ballots;
                add_new;
                caller;
                account = from;
                amount = ballot_amount(choice);
                timestamp = date;
            });
        };

        public func try_refund_ballots(time: Time) : async* [Nat] {
            let refunds = await* deposit_scheduler.try_refund(vote.ballot_register.ballots, time);
        };

//        func iter_locked_ballots() : Iter<(Nat, Lock)> {
//            var iter = Map.entries(vote.ballot_register.ballots);
//            func next() : ?(Nat, Lock) {
//                for ((id, ballot) in iter){
//                    switch(ballot.deposit_state){
//                        case(#LOCKED({expiration})){
//                            return ?(
//                                id, 
//                                {
//                                    amount = ballot_amount(ballot.choice);
//                                    timestamp = ballot.date;
//                                    decay = ballot.decay;
//                                    hotness = ballot.hotness;
//                                    expiration = expiration;
//                                }
//                            );
//                        };
//                        case(_) {};
//                    };
//                };
//                null;
//            };
//            { next; }
//        };
//
//        func update_ballot(id: Nat, lock: Lock) {
//            let updated_ballot = switch(Map.get(vote.ballot_register.ballots, Map.nhash, id)) {
//                case(null) { Debug.trap("Ballot not found"); }; // @todo
//                case(?b) { 
//                    { 
//                        b with 
//                        decay = lock.decay;
//                        hotness = lock.hotness;
//                        deposit_state = #LOCKED({expiration = lock.expiration});
//                    } 
//                };
//            };
//
//            Map.set(vote.ballot_register.ballots, Map.nhash, id, updated_ballot);
//        };
//
//        func add_ballot({
//            tx_id: Nat;
//            date: Time;
//            from: Account;
//            choice: B;
//            current_aggregate: A;
//        }) : (Lock) -> Nat {
//
//            func(lock: Lock) : Nat {
//                // Get the next ballot id
//                let ballot_id = vote.ballot_register.index;
//                vote.ballot_register.index := vote.ballot_register.index + 1;
//
//                // Add the ballot
//                Map.set(vote.ballot_register.ballots, Map.nhash, ballot_id, {
//                    tx_id;
//                    from;
//                    date;
//                    hotness = lock.hotness;
//                    decay = lock.decay;
//                    deposit_state = #LOCKED({expiration = lock.expiration});
//                    contest = compute_contest(current_aggregate, choice, date);
//                    choice;
//                });
//
//                // Return the ballot id
//                ballot_id;
//            };
//        };
    };

};