import Types          "../Types";
import PayementFacade "../PayementFacade";
import YieldScheduler  "../locks/YieldScheduler";

import Map            "mo:map/Map";

import Iter           "mo:base/Iter";
import Result         "mo:base/Result";
import Int            "mo:base/Int";
import Float          "mo:base/Float";

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

    public type UpdatePolicy<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeContest<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeScore<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
   
    public class VoteController<A, B>({
        update_aggregate: UpdatePolicy<A, B>;
        compute_contest: ComputeContest<A, B>;
        compute_score: ComputeScore<A, B>;
        yield_scheduler: YieldScheduler.YieldScheduler<Ballot<B>>;
    }){

        public func put_ballot({
            vote: Vote<A, B>;
            caller: Principal;
            from: Account;
            reward_account: Account;
            time: Time;
            amount: Nat;
            choice: B;
        }) : async* Result<Nat, AddDepositError> {

            func add_new(deposit_info: YieldScheduler.DepositInfo, lock_info: YieldScheduler.LockInfo) : (Nat, Ballot<B>){

                // Update the aggregate
                vote.aggregate := update_aggregate({aggregate = vote.aggregate; choice; amount; time;});

                // Get the next ballot id
                let ballot_id = vote.ballot_register.index;
                vote.ballot_register.index := vote.ballot_register.index + 1;

                // Add the ballot
                let ballot = {
                    tx_id = deposit_info.tx_id;
                    from;
                    reward_account;
                    timestamp = time;
                    hotness = lock_info.hotness;
                    decay = lock_info.decay;
                    deposit_state = deposit_info.state;
                    reward_state = #PENDING;
                    amount;
                    contest = compute_contest({ aggregate = vote.aggregate; choice; amount; time; });
                    choice;
                };
                Map.set(vote.ballot_register.ballots, Map.nhash, ballot_id, ballot);

                // Return the id and the ballot
                (ballot_id, ballot);
            };

            // Perform the deposit
            await* yield_scheduler.add_deposit({
                map = vote.ballot_register.ballots;
                add_new;
                caller;
                account = from;
                amount;
                timestamp = time;
            });
        };

        public func try_refund_and_reward({
            vote: Vote<A, B>;
            time: Time
        }) : async* [Nat] {
            await* yield_scheduler.try_refund_and_reward({
                map = vote.ballot_register.ballots;
                reward_amount = func({contest; choice; amount;}: Ballot<B>) : Nat {
                    Int.abs(Float.toInt(contest * compute_score({ aggregate = vote.aggregate; choice; amount; time; }))) * amount;
                };
                time;
            });
        };

    };

};
