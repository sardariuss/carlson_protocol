import Types          "../Types";
import PayementFacade "../PayementFacade";
import DepositScheduler "../locks/DepositScheduler";
import RewardScheduler  "../locks/RewardScheduler";

import Map            "mo:map/Map";

import Iter           "mo:base/Iter";
import Result         "mo:base/Result";
import Int            "mo:base/Int";
import Float          "mo:base/Float";
import Array          "mo:base/Array";

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

    public type PutBallotArgs = {
        caller: Principal;
        from: Account;
        reward_account: Account;
        time: Time;
        amount: Nat;
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        update_aggregate: UpdatePolicy<A, B>;
        compute_contest: ComputeContest<A, B>;
        compute_score: ComputeScore<A, B>;
        deposit_scheduler: DepositScheduler.DepositScheduler<Ballot<B>>;
        reward_scheduler: RewardScheduler.RewardScheduler<Ballot<B>>;
    }){

        public func new_vote({
            date: Time;
            author: Principal;
            tx_id: Nat;
        }) : Vote<A, B> {
            {
                date;
                author;
                tx_id;
                var aggregate = empty_aggregate;
                ballot_register = {
                    var index = 0;
                    ballots = Map.new<Nat, Ballot<B>>();
                };
            };
        };

        public func put_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PutBallotArgs;
        }) : async* Result<Nat, AddDepositError> {

            let { caller; from; reward_account; time; amount; } = args;

            func add_new(deposit_info: DepositScheduler.DepositInfo, lock_info: DepositScheduler.LockInfo) : (Nat, Ballot<B>){

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
            await* deposit_scheduler.add_deposit({
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

            let ballot_ids = await* deposit_scheduler.try_refund({
                map = vote.ballot_register.ballots;
                time;
            });

            label reward_loop for (ballot_id in Array.vals(ballot_ids)){
                let ballot = switch(Map.get(vote.ballot_register.ballots, Map.nhash, ballot_id)){
                    case (null) { continue reward_loop; }; // @todo
                    case (?b) { b; };
                };

                let score = compute_score({ aggregate = vote.aggregate; choice = ballot.choice; amount = ballot.amount; time; });
                let reward = Int.abs(Float.toInt(ballot.contest * score)) * ballot.amount;

                await* reward_scheduler.send_reward({
                    to = ballot;
                    amount = reward;
                    time;
                    update_elem = func(ballot: Ballot<B>) {
                        Map.set(vote.ballot_register.ballots, Map.nhash, ballot_id, ballot);
                    };
                });
                
            };

            ballot_ids;
        };

        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: Nat;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.ballots, Map.nhash, ballot_id);
        };

    };

};
