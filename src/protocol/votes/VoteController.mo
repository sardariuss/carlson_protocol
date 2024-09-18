import BallotBuilder      "BallotBuilder";
import Types              "../Types";
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

    type PutBallotError = Types.PutBallotError;
    type Account = Types.Account;
    type Iter<T> = Iter.Iter<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    public type UpdatePolicy<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;

    let TEMP_REWARD_MULTIPLIER = 1000;

    public type PutBallotArgs = {
        from: {
            owner: Principal;
            subaccount: ?Blob;
        };
        time: Time;
        amount: Nat;
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        update_aggregate: UpdatePolicy<A, B>;
        compute_dissent: ComputeDissent<A, B>;
        compute_consent: ComputeConsent<A, B>;
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

        public func preview_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PutBallotArgs;
        }) : Ballot<B> {

            let builder = intialize_ballot({ vote; choice; args; });

            deposit_scheduler.preview_deposit({
                register = vote.ballot_register;
                builder;
                args;
            });
        };

        public func put_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PutBallotArgs;
        }) : async* Result<Nat, PutBallotError> {

            let builder = intialize_ballot({ vote; choice; args; });

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
                    case (null) { continue reward_loop; }; // @todo: add an incident
                    case (?b) { b; };
                };

                let reward_fct = func() : async() {

                    let { choice; amount; dissent; timestamp; } = ballot;

                    let consent = compute_consent({ aggregate = vote.aggregate; choice; amount; time; });
                    let days_locked = toDays(time - timestamp);
                    let reward = TEMP_REWARD_MULTIPLIER * Int.abs(Float.toInt(days_locked * dissent * consent));

                    await* reward_dispenser.send_reward({
                        to = ballot;
                        amount = reward;
                        time;
                        update_elem = func(ballot: Ballot<B>) {
                            Map.set(vote.ballot_register.map, Map.nhash, ballot_id, ballot);
                        };
                    });
                };

                // Trigger the reward but do not wait for it to complete
                ignore reward_fct();
            };

            ballot_ids;
        };

        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: Nat;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.nhash, ballot_id);
        };

        func intialize_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PutBallotArgs;
        }) : BallotBuilder.BallotBuilder<B> {
            let { time; amount; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                timestamp = time;
                choice;
                amount;
                dissent = compute_dissent({
                    aggregate = vote.aggregate;
                    choice;
                    amount;
                    time;
                })
            });
            builder.add_reward({
                reward_account = args.from; // @todo: decide if the reward account shall be just removed or passed as an argument
                reward_state = #PENDING;
            });
            builder;
        };

    };

    func toDays(time: Time) : Float {
        Float.fromInt(time) / Float.fromInt(24 * 60 * 60 * 1_000_000_000);
    };

};
