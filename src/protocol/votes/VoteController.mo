import BallotBuilder      "BallotBuilder";
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

module {

    type Time = Int;

    type Account = Types.Account;
    type IDurationCalculator = DurationCalculator.IDurationCalculator;
    type UUID = Types.UUID;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

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

        public func preview_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let builder = build_ballot({ aggregate = vote.aggregate.current.data; choice; args; });

            hot_map.set_hot({ map = vote.ballot_register.map; builder; args; });
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
            let builder = build_ballot({ aggregate; choice; args; });
            switch(hot_map.add_new({ map; key = ballot_id; builder; args; })) {
                case(#err(_)) { Debug.trap("Error adding new ballot to hot map"); };
                case(#ok(ballot)) { ballot; };
            };
        };

        public func find_ballot({
            vote: Vote<A, B>;
            ballot_id: UUID;
        }) : ?Ballot<B> {
            Map.get(vote.ballot_register.map, Map.thash, ballot_id);
        };

        func build_ballot({
            aggregate: A;
            choice: B;
            args: PutBallotArgs;
        }) : BallotBuilder.BallotBuilder<B> {
            
            let { ballot_id; timestamp; amount; tx_id; from; } = args;

            let builder = BallotBuilder.BallotBuilder<B>({duration_calculator});
            builder.add_ballot({
                ballot_id;
                timestamp;
                choice;
                amount;
                dissent = compute_dissent({ aggregate; choice; amount; time = timestamp; });
                consent = Timeline.initialize(timestamp, compute_consent({ aggregate; choice; time = timestamp; }));
            });
            builder.add_deposit({ tx_id; from; });
            builder;
        };

    };

};
