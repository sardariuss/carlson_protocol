import VoteController     "VoteController";
import Conversion         "BallotConversion";
import Incentives         "Incentives";

import Types              "../Types";
import Decay              "../duration/Decay";
import DurationCalculator "../duration/DurationCalculator";
import PayementFacade     "../payement/PayementFacade";
import DepositScheduler   "../payement/DepositScheduler";
import RewardDispenser    "../payement/RewardDispenser";
import LockScheduler      "../locks/LockScheduler";
import HotMap             "../locks/HotMap";

import Map                "mo:map/Map";

import Float              "mo:base/Float";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;

    type Vote<A, B> = Types.Vote<A, B>;
    type VoteType = Types.VoteType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type YesNoChoice = Types.YesNoChoice;
    type RefundState = Types.RefundState;
    type Duration = Types.Duration;

    type HotElem = HotMap.HotElem;
    type Deposit = DepositScheduler.Deposit;
    type RewardInfo = RewardDispenser.RewardInfo;
    type Lock = LockScheduler.Lock;

    type Time = Int;

    public func build_yes_no({
        payement_facade: PayementFacade.PayementFacade;
        reward_facade: PayementFacade.PayementFacade;
        decay_model: Decay.DecayModel;
        duration_calculator: DurationCalculator.IDurationCalculator;
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

        func compute_dissent({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Incentives.compute_dissent({ 
                choice;
                amount = Float.fromInt(amount);
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        func compute_consent({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Incentives.compute_consent({
                choice;
                amount;
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        let hot_map = HotMap.HotMap<Nat, YesNoBallot>({
            decay_model;
            get_elem = func (b: YesNoBallot): HotElem { b; };
            update_elem = func (b: YesNoBallot, i: HotElem): YesNoBallot {
                { b with hotness = i.hotness; };
            };
            key_hash = Map.nhash;
        });

        let lock_scheduler = LockScheduler.LockScheduler<YesNoBallot>({
            hot_map;
            lock_info = func (b: YesNoBallot): Lock { b; };
        });

        let deposit_scheduler = DepositScheduler.DepositScheduler<YesNoBallot>({
            payement_facade;
            lock_scheduler;
            get_deposit = func (b: YesNoBallot): Deposit { b; };
            tag_refunded = func (b: YesNoBallot, s: RefundState): YesNoBallot { Conversion.tag_refunded<YesNoChoice>(b, s); };
        });

        let reward_dispenser = RewardDispenser.RewardDispenser<YesNoBallot>({
            reward_facade;
            get_reward = func (b: YesNoBallot): RewardInfo { Conversion.to_reward_info<YesNoChoice>(b); };
            update_reward = func (b: YesNoBallot, i: RewardInfo): YesNoBallot { Conversion.update_reward_info<YesNoChoice>(b, i); };
        });
        
        VoteController.VoteController<YesNoAggregate, YesNoChoice>({
            empty_aggregate;
            update_aggregate;
            compute_dissent;
            compute_consent;
            duration_calculator;
            deposit_scheduler;
            reward_dispenser;
        });
    };

};