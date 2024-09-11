import BallotBuilder      "BallotBuilder";
import Types              "../Types";
import PayementFacade     "../payement/PayementFacade";
import DepositScheduler   "../payement/DepositScheduler";
import RewardDispenser    "../payement/RewardDispenser";
import DurationCalculator "../duration/DurationCalculator";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Iter               "mo:base/Iter";
import Result             "mo:base/Result";
import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Array              "mo:base/Array";

module {

    type Time = Int;

    public type VoteId = Nat;

    type PayServiceError = PayementFacade.PayServiceError;
    type Account = Types.Account;
    type Iter<T> = Iter.Iter<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;

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
        duration_calculator: IDurationCalculator;
        deposit_scheduler: DepositScheduler.DepositScheduler<Ballot<B>>;
        reward_dispenser: RewardDispenser.RewardDispenser<Ballot<B>>;
    }){

        public func new_vote({
            vote_id: Nat;
            date: Time;
            origin: Principal;
        }) : Vote<A, B> {
            {
                vote_id;
                date;
                origin;
                var aggregate = empty_aggregate;
                ballot_register = {
                    var index = 0;
                    map = Map.new<Nat, Ballot<B>>();
                    locks = Set.new<Nat>();
                };
            };
        };

        public func put_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PutBallotArgs;
        }) : async* Result<Nat, PayServiceError> {

            let { time; amount; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                timestamp = time;
                choice;
                amount;
                contest = compute_contest({
                    aggregate = vote.aggregate;
                    choice;
                    amount;
                    time;
                })
            });
            builder.add_reward({
                reward_account = args.reward_account;
                reward_state = #PENDING;
            });

            // Update the aggregate only once the deposit is done
            let callback = func(ballot: Ballot<B>) {
                vote.aggregate := update_aggregate({ 
                    aggregate = vote.aggregate;
                    choice = ballot.choice;
                    amount = ballot.amount; 
                    time = ballot.timestamp;
                });
            };

            // Perform the deposit
            await* deposit_scheduler.add_deposit({
                register = vote.ballot_register;
                builder;
                callback;
                args;
            });
        };

        public func try_refund_and_reward({
            vote: Vote<A, B>;
            time: Time
        }) : async* [Nat] {

            let ballot_ids = await* deposit_scheduler.try_refund({
                register = vote.ballot_register;
                time;
            });

            label reward_loop for (ballot_id in Array.vals(ballot_ids)){
                let ballot = switch(Map.get(vote.ballot_register.map, Map.nhash, ballot_id)){
                    case (null) { continue reward_loop; }; // @todo
                    case (?b) { b; };
                };

                let score = compute_score({ aggregate = vote.aggregate; choice = ballot.choice; amount = ballot.amount; time; });
                let reward = Int.abs(Float.toInt(ballot.contest * score)) * ballot.amount;

                await* reward_dispenser.send_reward({
                    to = ballot;
                    amount = reward;
                    time;
                    update_elem = func(ballot: Ballot<B>) {
                        Map.set(vote.ballot_register.map, Map.nhash, ballot_id, ballot);
                    };
                });
                
            };

            ballot_ids;
        };

        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: Nat;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.nhash, ballot_id);
        };

    };

};
