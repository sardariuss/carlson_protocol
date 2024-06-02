import Types "../Types";
import VoteController "VoteController";
import Conversion "BallotConversion";

import SubaccountIndexer "../SubaccountIndexer";
import LockScheduler "../locks/LockScheduler";
import DepositScheduler "../locks/DepositScheduler";
import RewardScheduler "../locks/RewardScheduler";
import PayementFacade "../PayementFacade";
import Decay  "../Decay";
import Reward "../Reward";

import Float "mo:base/Float";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;

    type Vote<A, B> = Types.Vote<A, B>;
    type VoteType = Types.VoteType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type YesNoChoice = Types.YesNoChoice;

    type LockInfo = LockScheduler.LockInfo;
    type DepositInfo = DepositScheduler.DepositInfo;
    type RewardInfo = RewardScheduler.RewardInfo;

    type Time = Int;

    public func build({
        subaccount_indexer: SubaccountIndexer.SubaccountIndexer;
        payement_facade: PayementFacade.PayementFacade;
        reward_facade: PayementFacade.PayementFacade;
        decay_model: Decay.DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }) : VoteController<YesNoAggregate, YesNoChoice> {

        let empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };

        func update_aggregate({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time;}) : YesNoAggregate {
            switch(choice){
                case(#YES) {{
                    aggregate with 
                    total_yes = aggregate.total_yes + amount;
                    current_yes = Decay.add(aggregate.current_yes, decay_model.createDecayed(Float.fromInt(amount), time)); 
                }};
                case(#NO) {{
                    aggregate with 
                    total_no = aggregate.total_no + amount;
                    current_no = Decay.add(aggregate.current_no, decay_model.createDecayed(Float.fromInt(amount), time)); 
                }};
            };
        };

        func compute_contest({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Reward.compute_contest({ 
                choice;
                amount = Float.fromInt(amount);
                total_yes = decay_model.unwrapDecayed(aggregate.current_yes, time);
                total_no = decay_model.unwrapDecayed(aggregate.current_no, time);
            });
        };

        func compute_score({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Reward.compute_score({
                choice;
                amount;
                total_yes = decay_model.unwrapDecayed(aggregate.current_yes, time);
                total_no = decay_model.unwrapDecayed(aggregate.current_no, time);
            });
        };

        let lock_scheduler = LockScheduler.LockScheduler<YesNoBallot>({
            decay_model;
            get_lock_duration_ns;
            get_lock = func (b: YesNoBallot): LockInfo { Conversion.to_lock_info<YesNoChoice>(b); };
            update_lock = func (b: YesNoBallot, i: LockInfo): YesNoBallot { Conversion.update_lock_info<YesNoChoice>(b, i); };
        });

        let deposit_scheduler = DepositScheduler.DepositScheduler<YesNoBallot>({
            subaccount_indexer;
            payement_facade;
            lock_scheduler;
            get_deposit = func (b: YesNoBallot): DepositInfo { Conversion.to_deposit_info<YesNoChoice>(b); };
            update_deposit = func (b: YesNoBallot, i: DepositInfo): YesNoBallot { Conversion.update_deposit_info<YesNoChoice>(b, i); };
        });

        let reward_scheduler = RewardScheduler.RewardScheduler<YesNoBallot>({
            reward_facade;
            get_reward = func (b: YesNoBallot): RewardInfo { Conversion.to_reward_info<YesNoChoice>(b); };
            update_reward = func (b: YesNoBallot, i: RewardInfo): YesNoBallot { Conversion.update_reward_info<YesNoChoice>(b, i); };
        });
        
        VoteController.VoteController<YesNoAggregate, YesNoChoice>({
            empty_aggregate;
            update_aggregate;
            compute_contest;
            compute_score;
            deposit_scheduler;
            reward_scheduler;
        });
    };

};