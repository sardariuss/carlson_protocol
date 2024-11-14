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
    type VoteId = Types.VoteId;
    type BallotId = Types.BallotId;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    public type UpdateAggregate<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; time: Time}) -> Float;

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
        update_aggregate: UpdateAggregate<A, B>;
        compute_dissent: ComputeDissent<A, B>;
        compute_consent: ComputeConsent<A, B>;
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
                aggregate_history = { var entries = [{ timestamp = date; data = empty_aggregate; }] };
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

            let aggregate = update_aggregate({ args with aggregate = lastAggregate(vote); choice; });
            let builder = intialize_ballot({ choice; args; aggregate; });

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

            let aggregate = update_aggregate({ args with aggregate = lastAggregate(vote); choice; });
            let builder = intialize_ballot({ choice; args; aggregate; });

            // Update the aggregate only once the deposit is done
            let callback = func(ballot: Ballot<B>) {
                // Recompute the aggregate because other ballots might have been added during the awaited deposit, hence changing the aggregate.
                let aggregate = update_aggregate({ ballot with time = ballot.timestamp; aggregate = lastAggregate(vote); });
                // Update the aggregate history
                vote.aggregate_history.entries := Array.append(vote.aggregate_history.entries, [{ timestamp = ballot.timestamp; data = aggregate; }]);
                // Update the ballot consents
                for ((id, bal) in Map.entries(vote.ballot_register.map)) {
                    Map.set(vote.ballot_register.map, Map.nhash, id, { bal with consent = compute_consent({ aggregate; choice = bal.choice; time = bal.timestamp; }) });
                };
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
            time: Time;
            on_release_attempt: ReleaseAttempt<Ballot<B>> -> ();
        }) : async* () {

            await* deposit_scheduler.attempt_release({
                register = vote.ballot_register;
                time;
                on_release_attempt;
            });
        };

        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: Nat;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.nhash, ballot_id);
        };

        func intialize_ballot({
            aggregate: A;
            choice: B;
            args: PutBallotArgs;
        }) : BallotBuilder.BallotBuilder<B> {
            let { time; amount; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                timestamp = time;
                choice;
                amount;
                dissent = compute_dissent({ aggregate; choice; amount; time; });
                consent = compute_consent({ aggregate; choice; time; });
                presence = 0.0;
            });
            builder;
        };

    };

    func lastAggregate<A, B>(vote: Vote<A, B>) : A {
        let entries = vote.aggregate_history.entries;
        entries[Array.size(entries) - 1].data;
    };

    func toDays(time: Time) : Float {
        Float.fromInt(time) / Float.fromInt(24 * 60 * 60 * 1_000_000_000);
    };

};
