import Types          "Types";
import Decay          "Decay";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade "PayementFacade";

import Map            "mo:map/Map";

import Debug          "mo:base/Debug";
import Iter           "mo:base/Iter";
import Buffer         "mo:base/Buffer";
import Int            "mo:base/Int";
import Float          "mo:base/Float";
import Option         "mo:base/Option";
import Result         "mo:base/Result";
import Array          "mo:base/Array";

module {

    type VoteId = Nat;
    type Decayed = Types.Decayed;
    type ChoiceType = Types.ChoiceType;
    type VoteType = Types.VoteType;
    type Time = Int;
    type Duration = Types.Duration;
    type Account = Types.Account;

    type AddDepositResult = PayementFacade.AddDepositResult;

    type Register = {
        var index: VoteId;
        votes: Map.Map<VoteId, VoteType>;
    };

    public class Controller({
        register: Register;
        payement_facade: PayementFacade.PayementFacade;
    }){

        public func new_vote(timestamp: Time) : VoteId {

            // @todo: pay for the vote (to the main account)

            let id = votes.new_vote(timestamp);
            deposits.new_deposit_register(id);
            id;
        };

        public func add_ballot({
            timestamp: Time;
            vote_id: VoteId;
            voter: Principal;
            account: Account;
            choice: Choice;
        }) : async* AddDepositResult {
            
            // Perform the deposit
            let deposit_result = await* deposits.add_deposit({
                register_id = vote_id;
                caller = voter;
                account;
                amount = Choice.get_amount(choice);
                timestamp;
            });

            Result.iterate(deposit_result, func(tx_id: Nat){
                
                // Compute the contest
                let vote = votes.get_vote(vote_id); 
                let contest = Reward.compute_contest({
                    choice;
                    total_yes = decay_model.unwrapDecayed(vote.aggregate.yes, timestamp);
                    total_no = decay_model.unwrapDecayed(vote.aggregate.no, timestamp);
                });

                // Add the ballot
                votes.add_ballot({ vote_id; ballot = { id = tx_id; timestamp; voter; choice; contest; }; });
            });

            deposit_result;
        };


        public func try_unlock(time: Time) : async* [Nat] {
            
            let refunds = await* deposits.try_refund(time);

            for ({ register_id; original_tx_id; } in Array.vals(refunds)) {
                
            };

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