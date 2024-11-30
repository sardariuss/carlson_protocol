import BallotBuilder      "BallotBuilder";
import Types              "../Types";
import DepositScheduler   "../payement/DepositScheduler";
import DurationCalculator "../duration/DurationCalculator";
import Timeline           "../utils/Timeline";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Iter               "mo:base/Iter";
import Result             "mo:base/Result";
import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Time               "mo:base/Time";

module {

    type Time = Int;

    type PutBallotResult = Types.PutBallotResult;
    type Account = Types.Account;
    type Iter<T> = Iter.Iter<T>;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;
    type UUID = Types.UUID;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    type DepositState = Types.DepositState;

    public type UpdateAggregate<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; time: Time}) -> Float;

    public type PreviewBallotArgs = {
        from: {
            owner: Principal;
            subaccount: ?Blob;
        };
        time: Time;
        amount: Nat;
    };

    public type PutBallotArgs = PreviewBallotArgs and {
        ballot_id: UUID;
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
            vote_id: UUID;
            date: Time;
            origin: Principal;
        }) : Vote<A, B> {
            {
                vote_id;
                date;
                last_mint = date;
                origin;
                aggregate = Timeline.initialize(date, empty_aggregate);
                ballot_register = {
                    map = Map.new<UUID, Ballot<B>>();
                    locks = Set.new<UUID>();
                };
            };
        };

        public func preview_ballot({
            vote: Vote<A, B>;
            choice: B;
            args: PreviewBallotArgs;
        }) : Ballot<B> {

            let builder = intialize_ballot({ choice; args; aggregate = vote.aggregate.current.data; });

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
        }) : async* PutBallotResult {

            let { ballot_id; } = args;

            if (Map.has(vote.ballot_register.map, Map.thash, ballot_id)) {
                return #err(#BallotAlreadyExists({ ballot_id }));
            };

            let builder = intialize_ballot({ choice; args; aggregate = vote.aggregate.current.data; });

            // Update the aggregate only once the deposit is done
            let callback = func(ballot: Ballot<B>) {
                // Get the updated time after async call
                // TODO: should be Time.now() of the simulation instead
                let time = ballot.timestamp;
                // Recompute the aggregate because other ballots might have been added during the awaited deposit, hence changing the aggregate.
                let aggregate = update_aggregate({ ballot with time; aggregate = vote.aggregate.current.data; });
                // Update the aggregate history
                Timeline.add(vote.aggregate, time, aggregate);
                // Update the ballot consents
                for ((id, bal) in Map.entries(vote.ballot_register.map)) {
                    Timeline.add(bal.consent, time, compute_consent({ aggregate; choice = bal.choice; time; }));
                };
            };

            // Perform the deposit
            let deposit = await* deposit_scheduler.add_deposit({
                register = vote.ballot_register;
                builder;
                callback;
                args = { args with id = ballot_id; };
            });
            Result.mapOk(deposit, func(_: ()) : UUID { ballot_id; });
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
            ballot_id: UUID;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.thash, ballot_id);
        };

        func intialize_ballot({
            aggregate: A;
            choice: B;
            args: PreviewBallotArgs;
        }) : BallotBuilder.BallotBuilder<B> {
            let { time; amount; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                timestamp = time;
                choice;
                amount;
                dissent = compute_dissent({ aggregate; choice; amount; time; });
                consent = Timeline.initialize(time, compute_consent({ aggregate; choice; time; }));
                presence = Timeline.initialize(time, 0.0);
            });
            builder;
        };

    };

};
