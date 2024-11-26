import VoteController     "VoteController";
import Incentives         "Incentives";

import Types              "../Types";
import Decay              "../duration/Decay";
import DurationCalculator "../duration/DurationCalculator";
import PayementFacade     "../payement/PayementFacade";
import DepositScheduler   "../payement/DepositScheduler";
import LockScheduler      "../locks/LockScheduler";
import HotMap             "../locks/HotMap";
import Timeline            "../utils/Timeline";

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
    type TimedData<T> = Types.TimedData<T>;

    type HotElem = HotMap.HotElem;
    type Deposit = DepositScheduler.Deposit;
    type Lock = LockScheduler.Lock;

    type Time = Int;

    public func build_yes_no({
        deposit_facade: PayementFacade.PayementFacade;
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

        func compute_consent({aggregate: YesNoAggregate; choice: YesNoChoice; time: Time;}) : Float {
            Incentives.compute_consent({ 
                choice;
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        let hot_map = HotMap.HotMap<Nat, YesNoBallot>({
            decay_model;
            get_elem = func (b: YesNoBallot): HotElem { b; };
            update_hotness = func ({v: YesNoBallot; hotness: Float; time: Time}): YesNoBallot {
                let update = { v with hotness; };
                // Update the duration of the lock if the lock is still active
                // TODO: this logic shall be handled elsewhere, it feels like a hack
                if (v.timestamp + Timeline.get_current(v.duration_ns) > time){
                    Timeline.add(update.duration_ns, time, duration_calculator.compute_duration_ns({hotness}));
                };
                update;
            };
            key_hash = Map.nhash;
        });

        let lock_scheduler = LockScheduler.LockScheduler<YesNoBallot>({
            hot_map;
            lock_info = func (b: YesNoBallot): Lock {
                { timestamp = b.timestamp; duration_ns = Timeline.get_current(b.duration_ns); } 
            };
        });

        let deposit_scheduler = DepositScheduler.DepositScheduler<YesNoBallot>({
            deposit_facade;
            lock_scheduler;
            get_deposit = func (b: YesNoBallot): Deposit { b; };
            tag_refunded = func (b: YesNoBallot, s: RefundState): YesNoBallot { { b with deposit_state = #REFUNDED(s); } };
        });
        
        VoteController.VoteController<YesNoAggregate, YesNoChoice>({
            empty_aggregate;
            update_aggregate;
            compute_dissent;
            compute_consent;
            duration_calculator;
            deposit_scheduler;
        });
    };

};