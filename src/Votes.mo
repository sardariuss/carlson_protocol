import Types  "Types";
import Ballot "Ballot";
import Locks  "Locks";
import Reward "Reward";

import Map    "mo:map/Map";

import Debug  "mo:base/Debug";
import Iter   "mo:base/Iter";

module {

    type Vote = Types.Vote;
    type Time = Int;
    
    public class Votes({
        register: Types.VotesRegister;
        lock_params: Types.LocksParams;
    }){

        // Creates a new vote and add it to the list of votes
        public func new_vote(statement: Text) : Nat {
            let vote_id = register.index;
            register.index += 1;
            Map.set(register.votes, Map.nhash, vote_id, { 
                vote_id;
                statement; 
                total_ayes = 0;
                total_nays = 0;
                locks = Map.new<Nat, Types.TokensLock>();
            });
            vote_id;
        };

        // Find a vote by its id
        public func find_vote(vote_id: Nat): ?Types.Vote {
            Map.get(register.votes, Map.nhash, vote_id);
        };

        // Checks if the vote exists
        public func has_vote(vote_id: Nat): Bool {
            Map.has(register.votes, Map.nhash, vote_id);
        };

        public func iter(): Iter.Iter<Types.Vote> {
            Map.vals(register.votes);
        };

        // Vote (by adding the given ballot)
        // Assumes that the vote exists
        public func put_ballot({
            vote_id: Nat; 
            tx_id: Nat;
            from: Types.Account;
            timestamp: Time;
            ballot: Types.Ballot;
        }){
            // Get the vote
            var vote = switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };

            // Compute the contest factor
            let contest_factor = Reward.compute_contest_factor({ ballot; vote; });

            // Add a lock for the given amount
            let locks = Locks.Locks({ lock_params; locks = vote.locks;});
            locks.add_lock({ tx_id; from; contest_factor; timestamp; ballot; });

            // Update the aye or nay total with the amount from the given ballot
            switch(ballot){
                case(#AYE(amount)) { vote := { vote with total_ayes = vote.total_ayes + amount; }; };
                case(#NAY(amount)) { vote := { vote with total_nays = vote.total_nays + amount; }; };
            };

            // Update the vote
            Map.set(register.votes, Map.nhash, vote_id, vote);
        };

        public func preview_contest_factor({
            vote_id: Nat;
            ballot: Types.Ballot;
        }) : { #ok: Float; #err: {#VoteNotFound}; } {
            switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { #err(#VoteNotFound); };
                case(?vote) { #ok(Reward.compute_contest_factor({ ballot; vote; })); };
            };
        };

    };

}