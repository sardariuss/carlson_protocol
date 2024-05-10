import Types          "Types";
import Choice         "Choice";
import Decay          "Decay";
import Reward         "Reward";
import YesNoVote      "votes/YesNoVote";
import VotePolicy     "votes/VotePolicy";
import LockController "locks/LockController";
import LockScheduler  "locks/LockScheduler";

import Map            "mo:map/Map";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";
import Buffer         "mo:base/Buffer";
import Int            "mo:base/Int";
import Float          "mo:base/Float";
import Option         "mo:base/Option";

module {

    type VoteId = Nat;
    type Decayed = Types.Decayed;
    type Choice = Types.Choice;
    type Time = Int;
    type Duration = Types.Duration;

    type YesNoAggregate = YesNoVote.YesNoAggregate;
    type YesNoBallot = YesNoVote.YesNoBallot;
    type Vote = VotePolicy.Vote<YesNoAggregate, YesNoBallot>;
    type Lock = LockScheduler.Lock;

    type Register = {
        var index: VoteId;
        votes: Map.Map<VoteId, Vote>;
        locks: Map.Map<VoteId, Map.Map<Nat, Lock>>;
    };

    public type Unlock = { account: Types.Account; refund: Nat; reward: Nat; };

    public class Controller({
        register: Register;
        get_lock_duration_ns: Float -> Nat;
        half_life: Duration; 
        time_init: Time;
    }){

        let _decay_model = Decay.DecayModel({
            half_life;
            time_init;
        });

        let _lock_controller = LockController.LockController({
            locks = register.locks;
            get_lock_duration_ns;
            decay_model = _decay_model;
        });

        let _votes = YesNoVote.build({
            votes = register.votes;
            decay_model = _decay_model;
        });

        public func new_vote(timestamp: Time) : VoteId {
            let id = register.index;
            register.index += 1;
            _votes.new_vote({ id; timestamp; });
            _lock_controller.new_locks(id);
            id;
        };

        public func add_ballot({
            vote_id: VoteId;
            tx_id: Nat;
            choice: Choice;
            timestamp: Time;
            voter: Principal;
        }){
            // Add the lock
            _lock_controller.add_lock({
                map_id = vote_id;
                lock_id = tx_id;
                amount = Choice.get_amount(choice);
                timestamp;
            });

            // Compute the contest
            let vote = _votes.get_vote(vote_id); 
            let contest = Reward.compute_contest({
                choice;
                total_yes = _decay_model.unwrapDecayed(vote.aggregate.yes, timestamp);
                total_no = _decay_model.unwrapDecayed(vote.aggregate.no, timestamp);
            });

            // Add the ballot
            _votes.add_ballot({ vote_id; ballot = { id = tx_id; timestamp; voter; choice; contest; }; });
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

    };

};