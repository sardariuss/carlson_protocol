import Types "Types";
import Ballot "Ballot";
import Locks "Locks";

import Map "mo:map/Map";

import Debug "mo:base/Debug";

module {

    type Vote = Types.Vote;
    type Time = Int;
    
    public class Votes({
        data: Types.VotesData;
        lock_params: Types.LocksParams;
    }){

        // Creates a new vote and add it to the list of votes
        public func new_vote(statement: Text){           
            Map.set(data.votes, Map.nhash, data.index, { 
                vote_id = data.index;
                statement; 
                total_ayes = 0;
                total_nays = 0;
                locks = Map.new<Nat, Types.TokensLock>();
            });
            data.index += 1;
        };

        // Find a vote by its id
        public func find_vote(vote_id: Nat): ?Types.Vote {
            Map.get(data.votes, Map.nhash, vote_id);
        };

        // Checks if the vote exists
        public func has_vote(vote_id: Nat): Bool {
            Map.has(data.votes, Map.nhash, vote_id);
        };

        // Vote (by adding the given ballot)
        // Assumes that the vote exists
        public func put_ballot({
            vote_id: Nat; 
            tx_id: Nat;
            from: Types.Account;
            timestamp: Time;
            ballot: Types.Ballot
        }){
            
            // Get the vote
            var vote = switch(Map.get(data.votes, Map.nhash, vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };

            // Update the aye or nay total with the amount from the given ballot
            switch(ballot){
                case(#AYE(amount)) { vote := { vote with total_ayes = vote.total_ayes + amount; }; };
                case(#NAY(amount)) { vote := { vote with total_nays = vote.total_nays + amount; }; };
            };

            // Add a lock for the given amount
            let locks = Locks.Locks({ lock_params; locks = vote.locks;});
            locks.add_lock({ tx_id; from; timestamp; ballot; });

            // Update the vote
            Map.set(data.votes, Map.nhash, vote_id, vote);
        };

    };
}