import BallotBuilder      "BallotBuilder";
import DebtProcessor      "../DebtProcessor";
import Types              "../Types";
import DurationCalculator "../duration/DurationCalculator";
import Timeline           "../utils/Timeline";
import HotMap             "../locks/HotMap";
import Decay              "../duration/Decay";  

import Set                "mo:map/Set";

import Result             "mo:base/Result";
import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Time               "mo:base/Time";
import Debug              "mo:base/Debug";
import Iter               "mo:base/Iter";

module {

    type Time = Int;

    type Account = Types.Account;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type UUID = Types.UUID;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Set<K> = Set.Set<K>;
    type Iter<T> = Iter.Iter<T>;

    type Vote<A, B> = Types.Vote<A, B>;

    type Ballot<B> = Types.Ballot<B>;

    public type UpdateAggregate<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; time: Time}) -> Float;

    public type PutBallotArgs = {
        ballot_id: UUID;
        timestamp: Time;
        amount: Nat;
        tx_id: Nat;
        from: Account;
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        update_aggregate: UpdateAggregate<A, B>;
        compute_dissent: ComputeDissent<A, B>;
        compute_consent: ComputeConsent<A, B>;
        duration_calculator: IDurationCalculator;
        decay_model: Decay.DecayModel;
        hot_map: HotMap.HotMap;
        iter_ballots: () -> Iter<(UUID, Ballot<B>)>;
        add_ballot: (UUID, Ballot<B>) -> ();
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
                ballots = Set.new<UUID>();
            };
        };

        public func preview_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let { vote_id } = vote;
            let { amount; timestamp; } = args;
            let time = timestamp;
            var aggregate = vote.aggregate.current.data;

            // Compute the dissent before updating the aggregate
            let dissent = compute_dissent({ aggregate; choice; amount; time; });
            
            // Update the aggregate then compute the consent
            aggregate := update_aggregate({ aggregate; choice; amount; time; });
            let consent = compute_consent({ aggregate; choice; time; });

            let ballot = init_ballot({vote_id; choice; args; dissent; consent; });
            hot_map.add_new(vote_ballots(vote), ballot, false);

            ballot;
        };

        public func put_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let { vote_id } = vote;
            let { ballot_id; amount; timestamp; } = args;
            let time = timestamp;

            if (Set.has(vote.ballots, Set.thash, ballot_id)) {
                Debug.trap("A ballot with the ID " # args.ballot_id # " already exists");
            };

            var aggregate = vote.aggregate.current.data;

            // Compute the dissent before updating the aggregate
            let dissent = compute_dissent({ aggregate; choice; amount; time; });
            
            // Update the aggregate
            aggregate := update_aggregate({ aggregate; choice; amount; time; });
            Timeline.add(vote.aggregate, timestamp, aggregate);
            
            // Compute the consent
            let consent = compute_consent({ aggregate; choice; time; });

            // Update the ballot consents
            for (ballot in vote_ballots(vote)) {
                Timeline.add(ballot.consent, timestamp, compute_consent({ aggregate; choice; time; }));
            };

            // Update the hotness
            let ballot = init_ballot({vote_id; choice; args; dissent; consent; });
            hot_map.add_new(vote_ballots(vote), ballot, true);

            // Add the ballot
            add_ballot(ballot_id, ballot);
            Set.add(vote.ballots, Set.thash, ballot_id);

            ballot;
        };

        // @todo: remove this function
        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: UUID;
        }) : ?Ballot<B> {
            null;
        };

        func init_ballot({
            vote_id: UUID;
            choice: B;
            args: PutBallotArgs;
            dissent: Float;
            consent: Float;
        }) : Ballot<B> {
            let { timestamp; from; } = args;

            let ballot : Ballot<B> = {
                args with
                vote_id;
                choice;
                dissent;
                consent = Timeline.initialize<Float>(timestamp, consent);
                ck_btc = DebtProcessor.init_debt_info(timestamp, from);
                presence = DebtProcessor.init_debt_info(timestamp, from);
                resonance = DebtProcessor.init_debt_info(timestamp, from);
                decay = decay_model.compute_decay(timestamp);
                // @todo: shall be init with null
                var hotness = 0.0;
                duration_ns = Timeline.initialize<Nat>(timestamp, duration_calculator.compute_duration_ns(0.0));
                var release_date = -1;
            };
            ballot;
        };

        func vote_ballots(vote: Vote<A, B>) : Iter<Ballot<B>> {
            let it = iter_ballots();
            func next() : ?(Ballot<B>) {
                label get_next while(true) {
                    switch(it.next()){
                        case(null) { break get_next; };
                        case(?(id, ballot)) { 
                            if (Set.has(vote.ballots, Set.thash, id)) {
                                return ?ballot;
                            };
                        };
                    };
                };
                null;
            };
            return { next };
        };

    };

};
