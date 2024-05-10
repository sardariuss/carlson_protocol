import Types          "Types";
import Choice         "Choice";
import Decay          "Decay";
import LockScheduler  "LockScheduler";
import Reward         "Reward";

import Map            "mo:map/Map";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";
import Buffer         "mo:base/Buffer";
import Int            "mo:base/Int";
import Float          "mo:base/Float";

module {

    type Vote = Types.Vote;
    type Decayed = Types.Decayed;
    type Choice = Types.Choice;
    type Time = Int;

    public type Unlock = { account: Types.Account; refund: Nat; reward: Nat; };
    
    public class Votes({
        register: Types.VotesRegister;
        lock_scheduler: LockScheduler.LockScheduler<Types.Ballot>;
        decay_model: Decay.DecayModel;
    }){

        // Creates a new vote and add it to the list of votes
        public func new_vote(statement: Text) : Nat {
            let vote_id = register.index;
            register.index += 1;
            Map.set(register.votes, Map.nhash, vote_id, { 
                vote_id;
                statement; 
                total_yes = #DECAYED(0.0);
                total_no = #DECAYED(0.0);
                ballots = Map.new<Nat, Types.Ballot>();
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
        public func add_ballot({
            vote_id: Nat; 
            tx_id: Nat;
            from: Types.Account;
            timestamp: Time;
            choice: Choice;
        }) : Types.Ballot {
            
            // Get the vote
            let { ballots; total_yes; total_no; } = switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) { v };
            };

            // Add a lock for the given amount
            let ballot = lock_scheduler.new_lock({
                map = ballots;
                id = tx_id;
                amount = Choice.get_amount(choice);
                timestamp;
                new = new_ballot({
                    from;
                    choice; 
                    // Watchout: the method "compute_contest" assumes the vote 
                    // totals have not been updated yet with the new ballot
                    // @todo: is there a way to not make this assumption? Maybe by passing the updated total as argument?
                    contest = compute_contest({choice; total_yes; total_no; time = timestamp;})
                });
            });

            // Update the totals
            ignore Map.update<Nat, Vote>(register.votes, Map.nhash, vote_id, func(id: Nat, vote: ?Vote): ?Vote {
                switch(vote){
                    case(null) { Debug.trap("Vote not found"); };
                    case(?v) {
                        switch(choice){
                            case(#YES(amount)) { ?{ v with total_yes = Decay.add(v.total_yes, #DECAYED(Float.fromInt(amount) * ballot.decay)); } };
                            case(#NO(amount)) { ?{ v with total_no = Decay.add(v.total_no, #DECAYED(Float.fromInt(amount) * ballot.decay)); } };
                        };
                    };
                };
            });

            ballot;
        };

        public func preview_contest({
            vote_id: Nat;
            choice: Choice;
            time: Time;
        }) : { #ok: Float; #err: {#VoteNotFound}; } {
            switch(Map.get(register.votes, Map.nhash, vote_id)){
                case(null) { #err(#VoteNotFound); };
                case(?{ total_yes; total_no; }) { 
                    #ok(compute_contest({ choice; total_yes; total_no; time; }));
                };
            };
        };

        public func try_unlock(time: Time) : Buffer.Buffer<Unlock>{
            
            let buffer = Buffer.Buffer<Unlock>(0);

            for ({ total_yes; total_no; ballots; } in Map.vals(register.votes)) {
                buffer.append(Buffer.map(lock_scheduler.try_unlock({ map = ballots; time; }), func(ballot: Types.Ballot) : Unlock {
                    let { from; choice; contest; } = ballot;
                    let score = Reward.compute_score({ 
                        choice;
                        total_yes = decay_model.unwrapDecayed(total_yes, time);
                        total_no = decay_model.unwrapDecayed(total_no, time);
                    });
                    {
                        account = from;
                        refund = Choice.get_amount(choice);
                        reward = Int.abs(Float.toInt(contest * score));
                    };
                }));
            };

            buffer;
        };

        func compute_contest({
            choice: Choice;
            total_yes: Decayed;
            total_no: Decayed;
            time: Time;
        }) : Float {
            Reward.compute_contest({ 
                choice;
                total_yes = decay_model.unwrapDecayed(total_yes, time);
                total_no = decay_model.unwrapDecayed(total_no, time);
            });
        };

    };

    // Utility function to convert a ballot to a lock
    public func to_lock(ballot: Types.Ballot) : LockScheduler.Lock {
        { 
            id = ballot.tx_id;
            amount = Choice.get_amount(ballot.choice);
            timestamp = ballot.timestamp;
            hotness = ballot.hotness;
            decay = ballot.decay;
            lock_state = ballot.lock_state;
        };
    };

    // Utility function to update a ballot from a lock
    public func update_lock(
        ballot: Types.Ballot,
        lock: LockScheduler.Lock
    ) : Types.Ballot {
        {
            ballot with
            amount = lock.amount;
            timestamp = lock.timestamp;
            hotness = lock.hotness;
            decay = lock.decay;
            lock_state = lock.lock_state;
        };
    };

    // Utility function to create a new ballot from ballot arguments and lock info
    public func new_ballot({
        from: Types.Account;
        choice: Choice;
        contest: Float;
    }) : (LockScheduler.Lock) -> Types.Ballot {
        func(lock: LockScheduler.Lock) : Types.Ballot {
            {
                tx_id = lock.id;
                timestamp = lock.timestamp;
                hotness = lock.hotness;
                decay = lock.decay;
                lock_state = lock.lock_state;
                from;
                choice;
                contest;
            };
        };  
    };

};