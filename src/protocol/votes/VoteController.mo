import BallotBuilder      "BallotBuilder";
import Types              "../Types";
import DepositScheduler   "../payement/DepositScheduler";
import RewardDispenser    "../payement/RewardDispenser";
import MintController     "../payement/MintController";
import DurationCalculator "../duration/DurationCalculator";
import MapUtils           "../utils/Map";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Iter               "mo:base/Iter";
import Result             "mo:base/Result";
import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Array              "mo:base/Array";

module {

    type Time = Int;

    type PutBallotError = Types.PutBallotError;
    type Account = Types.Account;
    type Iter<T> = Iter.Iter<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type DatedAggregate<A> = Types.DatedAggregate<A>;
    type VoteId = Types.VoteId;
    type BallotId = Types.BallotId;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    public type UpdatePolicy<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;

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
        duration_calculator: IDurationCalculator;
        deposit_scheduler: DepositScheduler.DepositScheduler<Ballot<B>>;
    }){

        public func new_vote({
            vote_id: Nat;
            date: Time;
            origin: Principal;
        }) : Vote<A, B> {
            {
                vote_id;
                date;
                last_mint = date;
                origin;
                var aggregate_history = [{ date; aggregate = empty_aggregate; }];
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
                let aggregate = update_aggregate({ 
                    aggregate = lastAggregate(vote);
                    choice = ballot.choice;
                    amount = ballot.amount; 
                    time = ballot.timestamp;
                });

                vote.aggregate_history := Array.append(vote.aggregate_history, [{ date = ballot.timestamp; aggregate; }]);
            };

            // Perform the deposit
            await* deposit_scheduler.add_deposit({
                register = vote.ballot_register;
                builder;
                callback;
                args;
            });
        };

        public func try_release({
            vote: Vote<A, B>;
            on_release_attempt: ({ vote: Vote<A, B>; ballot: Ballot<B>; update_ballot: (Ballot<B>) -> (); released: ?Time;  }) -> ();
            time: Time;
        }) : async* () {

            await* deposit_scheduler.attempt_release({
                register = vote.ballot_register;
                time;
                on_release_attempt = func({elem: Ballot<B>; update_elem: (Ballot<B>) -> (); release_time: ?Time; }) {
                    on_release_attempt({
                        vote;
                        ballot = elem;
                        update_ballot = update_elem;
                        released = release_time;
                    });
                };
            });
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
                    aggregate = lastAggregate(vote);
                    choice;
                    amount;
                    time;
                });
                accumulated_reward = 0;
            });
            builder;
        };

    };

    func lastAggregate<A, B>(vote: Vote<A, B>) : A {
        vote.aggregate_history[Array.size(vote.aggregate_history) - 1].aggregate;
    };

    func toDays(time: Time) : Float {
        Float.fromInt(time) / Float.fromInt(24 * 60 * 60 * 1_000_000_000);
    };

};
