import BallotBuilder      "BallotBuilder";
import DebtProcessor      "../DebtProcessor";
import Types              "../Types";
import DurationCalculator "../duration/DurationCalculator";
import Timeline           "../utils/Timeline";
import HotMap             "../locks/HotMap";

import Map                "mo:map/Map";
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
    type Map<K, V> = Map.Map<K, V>;
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
        hot_map: HotMap.HotMap<UUID, Ballot<B>>;
        iter_ballots: () -> Iter<(UUID, Ballot<B>)>;
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
                ballot_register = {
                    map = Map.new<UUID, Ballot<B>>();
                };
            };
        };

        public func preview_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let builder = build_ballot({ vote_id = vote.vote_id; aggregate = vote.aggregate.current.data; choice; args; });

            hot_map.add_new({ iter = vote_ballots(vote); builder; args; update_map = false; });
        };

        public func put_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let { ballot_id; amount; timestamp; } = args;
            let { map } = vote.ballot_register;

            if (Map.has(map, Map.thash, ballot_id)) {
                Debug.trap("A ballot with the ID " # args.ballot_id # " already exists");
            };

            // Update the aggregate
            var aggregate = vote.aggregate.current.data;
            aggregate := update_aggregate({ choice; amount; time = timestamp; aggregate; });
            Timeline.add(vote.aggregate, timestamp, aggregate);

            // Update the ballot consents
            for ((id, bal) in Map.entries(map)) {
                Timeline.add(bal.consent, timestamp, compute_consent({ aggregate; choice; time = timestamp; }));
            };

            // Update the hotness
            let builder = build_ballot({ vote_id = vote.vote_id; aggregate; choice; args; });
            hot_map.add_new({ iter = vote_ballots(vote); builder; args; update_map = true; });
        };

        // @todo: remove this function
        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: UUID;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.thash, ballot_id);
        };

        func build_ballot({
            vote_id: UUID;
            aggregate: A;
            choice: B;
            args: PutBallotArgs;
        }) : BallotBuilder.BallotBuilder<B> {
            
            let { ballot_id; timestamp; amount; tx_id; from; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                vote_id;
                ballot_id;
                timestamp;
                choice;
                amount;
                dissent = compute_dissent({ aggregate; choice; amount; time = timestamp; });
                consent = Timeline.initialize(timestamp, compute_consent({ aggregate; choice; time = timestamp; }));
                ck_btc = DebtProcessor.init_debt_info(timestamp, from);
                presence = DebtProcessor.init_debt_info(timestamp, from);
                resonance = DebtProcessor.init_debt_info(timestamp, from);
            });
            builder.add_deposit({ tx_id; from; });
            builder;
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
