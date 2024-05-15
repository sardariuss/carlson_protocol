import Map            "mo:map/Map";
import Set            "mo:map/Set";
import VotePolicy     "VotePolicy";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";

module {

    type Time = Int;

    public type VoteId = Nat;

    type Vote<A, B> = VotePolicy.Vote<A, B>;
    type UpdatePolicy<A, B> = VotePolicy.UpdatePolicy<A, B>;

    public type Register<A, B> = {
        var index: VoteId;
        votes: Map.Map<VoteId, Vote<A, B>>;
    };
   
    public class VoteController<A, B>({
        register: Register<A, B>;
        empty_aggregate: A;
        add_to_aggregate: UpdatePolicy<A, B>;
        ballot_hash: Map.HashUtils<B>;
    }){

        let _policy = VotePolicy.VotePolicy<A, B>({
            add_to_aggregate = add_to_aggregate;
            ballot_hash = ballot_hash;
        });

        // Creates a new vote with the given ID and add it to the list of votes
        public func new_vote(timestamp: Time) : Nat {
            let id = register.index;
            register.index += 1;
            Map.set(register.votes, Map.nhash, id, {
                id;
                timestamp;
                ballots = Set.new<B>();
                var aggregate = empty_aggregate;
            });
            id;
        };

        // Get a vote by its id
        public func get_vote(vote_id: VoteId): Vote<A, B> {
            switch(find_vote(vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };
        };

        // Find a vote by its id
        public func find_vote(vote_id: VoteId): ?Vote<A, B> {
            Map.get(register.votes, Map.nhash, vote_id);
        };

        // Checks if the vote exists
        public func has_vote(vote_id: VoteId): Bool {
            Map.has(register.votes, Map.nhash, vote_id);
        };

        public func iter(): Iter.Iter<Vote<A, B>> {
            Map.vals(register.votes);
        };

        // Vote (by adding the given ballot)
        // Trap if the vote does not exist or if the ballot has already been added
        public func add_ballot({
            vote_id: VoteId;
            ballot: B;
        }) {

            // Get the vote
            let vote = switch(find_vote(vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };

            // Update the vote
            _policy.add_ballot({ vote; ballot; });
        };
    };

};