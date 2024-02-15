import Types          "Types";
import Choice         "Choice";
import LockScheduler  "LockScheduler";
import Reward         "Reward";

import Map            "mo:map/Map";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";
import Buffer         "mo:base/Buffer";

module {

    type Vote = Types.Vote;
    type Time = Int;

    public type Unlock = { account: Types.Account; refund: Nat; reward: Nat; };
    
    public class Votes({
        register: Types.VotesRegister;
        lock_scheduler: LockScheduler.LockScheduler<Types.Ballot>;
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
                locked_ballots = Map.new<Nat, Types.Ballot>();
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
            choice: Types.Choice;
        }) : Types.Ballot {
            
            // Get the vote
            let vote = switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };

            // Update the totals
            switch(choice){
                case(#AYE(amount)) { Map.set(register.votes, Map.nhash, vote_id, { vote with total_ayes = vote.total_ayes + amount; }); };
                case(#NAY(amount)) { Map.set(register.votes, Map.nhash, vote_id, { vote with total_nays = vote.total_nays + amount; }); };
            };

            // Add a lock for the given amount
            lock_scheduler.new_lock({ map = vote.locked_ballots; id = tx_id; amount = Choice.get_amount(choice); timestamp; from_lock = func(lock: LockScheduler.Lock) : Types.Ballot {
                {
                    tx_id;
                    from;
                    choice;
                    // Watchout: the method "compute_contest_factor" assumes the vote 
                    // totals have not been updated yet with the new ballot
                    contest_factor = Reward.compute_contest_factor({ choice; vote; });
                    timestamp;
                    time_left = lock.time_left;
                    rates = lock.rates;
                };
            }});
        };

        public func preview_contest_factor({
            vote_id: Nat;
            choice: Types.Choice;
        }) : { #ok: Float; #err: {#VoteNotFound}; } {
            switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { #err(#VoteNotFound); };
                case(?vote) { #ok(Reward.compute_contest_factor({ choice; vote; })); };
            };
        };

        public func try_unlock(time: Time) : Buffer.Buffer<Unlock>{
            
            let buffer = Buffer.Buffer<Unlock>(0);

            for ({ total_ayes; total_nays; locked_ballots; } in Map.vals(register.votes)) {
                buffer.append(Buffer.map(lock_scheduler.try_unlock({ map = locked_ballots; time; }), func(ballot: Types.Ballot) : Unlock {
                    {
                        account = ballot.from;
                        refund = Choice.get_amount(ballot.choice);
                        reward = Reward.compute_reward({ total_ayes; total_nays; ballot; });
                    };
                }));
            };

            buffer;
        };

    };

    // Utility function to convert a tokens lock to a lock scheduler lock
    public func to_lock(ballot : Types.Ballot) : LockScheduler.Lock {
        { id = ballot.tx_id; amount = Choice.get_amount(ballot.choice); timestamp = ballot.timestamp; time_left = ballot.time_left; rates = ballot.rates; };
    };

};