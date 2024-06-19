import VoteController    "VoteController";
import Conversion        "BallotConversion";
import Types             "../Types";
import TimeoutCalculator "../TimeoutCalculator";

import SubaccountIndexer "../payement/SubaccountIndexer";
import PayementFacade    "../payement/PayementFacade";
import LockScheduler     "../locks/LockScheduler";
import DepositScheduler  "../locks/DepositScheduler";
import RewardScheduler   "../locks/RewardScheduler";
import HotMap            "../locks/HotMap";
import Decay             "../Decay";
import Incentives        "../Incentives";

import Map               "mo:map/Map";

import Float             "mo:base/Float";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;

    type Vote<A, B> = Types.Vote<A, B>;
    type VoteType = Types.VoteType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type YesNoChoice = Types.YesNoChoice;
    type RefundState = Types.RefundState;
    type Duration = Types.Duration;

    type HotInfo = HotMap.HotInfo;
    type DepositInfo = DepositScheduler.DepositInfo;
    type RewardInfo = RewardScheduler.RewardInfo;

    type Time = Int;

    public func build_yes_no({
        subaccount_indexer: SubaccountIndexer.SubaccountIndexer;
        payement_facade: PayementFacade.PayementFacade;
        reward_facade: PayementFacade.PayementFacade;
        decay_model: Decay.DecayModel;
        timeout_calculator: TimeoutCalculator.ITimeoutCalculator;
    }) : VoteController<YesNoAggregate, YesNoChoice> {

        let empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };

        func update_aggregate({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time;}) : YesNoAggregate {
            switch(choice){
                case(#YES) {{
                    aggregate with 
                    total_yes = aggregate.total_yes + amount;
                    current_yes = Decay.add(aggregate.current_yes, decay_model.create_decayed(Float.fromInt(amount), time)); 
                }};
                case(#NO) {{
                    aggregate with 
                    total_no = aggregate.total_no + amount;
                    current_no = Decay.add(aggregate.current_no, decay_model.create_decayed(Float.fromInt(amount), time)); 
                }};
            };
        };

        func compute_contest({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Incentives.compute_contest({ 
                choice;
                amount = Float.fromInt(amount);
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        func compute_score({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Incentives.compute_score({
                choice;
                amount;
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        let hot_map = HotMap.HotMap<Nat, YesNoBallot>({
            decay_model;
            get_elem = func (b: YesNoBallot): HotInfo { b; };
            update_elem = func (b: YesNoBallot, i: HotInfo): YesNoBallot {
                { 
                    b with 
                    hotness = b.hotness; 
                    // Update the locked state if applicable
                    deposit_state = switch(b.deposit_state){
                        case(#LOCKED(_)) { #LOCKED{ until = timeout_calculator.timeout_date(b); }; };
                        case(other) { other; };
                    };
                };
            };
            key_hash = Map.nhash;
        });

        let lock_scheduler = LockScheduler.LockScheduler<YesNoBallot>({
            hot_map;
            timeout_calculator;
            hot_info = func (b: YesNoBallot): HotInfo { b; };
        });

        let deposit_scheduler = DepositScheduler.DepositScheduler<YesNoBallot>({
            subaccount_indexer;
            payement_facade;
            lock_scheduler;
            get_deposit = func (b: YesNoBallot): DepositInfo { b; };
            tag_refunded = func (b: YesNoBallot, s: RefundState): YesNoBallot { Conversion.tag_refunded<YesNoChoice>(b, s); };
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
            timeout_calculator;
        });
    };

};