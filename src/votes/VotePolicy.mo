import Set            "mo:map/Set";

import Debug          "mo:base/Debug";

module {

    type Time = Int;

    public type VoteId = Nat;

    public type Vote<A, B> = {
        id: VoteId;
        timestamp: Time;
        var aggregate: A;
        ballots: Set.Set<B>;
    };

    public type UpdatePolicy<A, B> = ({aggregate: A; ballot: B;}) -> A;
    
    public class VotePolicy<A, B>({
        add_to_aggregate: UpdatePolicy<A, B>;
        ballot_hash: Set.HashUtils<B>;
    }){

        // Vote (by adding the given ballot)
        // Trap if the vote does not exist or if the ballot has already been added
        public func add_ballot({
            vote: Vote<A, B>;
            ballot: B;
        }) {

            // Add the ballot
            if (Set.has(vote.ballots, ballot_hash, ballot)){
                Debug.trap("A ballot with the same hash has already been added to the vote");
            };
            Set.add(vote.ballots, ballot_hash, ballot);

            // Update the aggregate
            vote.aggregate := add_to_aggregate({aggregate = vote.aggregate; ballot;});
        };
    };

};