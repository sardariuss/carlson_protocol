import Types              "Types";
import Controller         "Controller";
import Decay              "duration/Decay";
import DurationCalculator "duration/DurationCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import PresenceDispenser  "PresenceDispenser";
import LockScheduler2     "LockScheduler2";
import Clock              "utils/Clock";
import HotMap             "locks/HotMap";
import Timeline           "utils/Timeline";
import DebtProcessor      "DebtProcessor";
import PresenceDispenser2 "PresenceDispenser2";

import Map                "mo:map/Map";

module {

    type VoteRegister = Types.VoteRegister;
    type Duration = Types.Duration;
    type Time = Int;
    type State = Types.State;
    type Lock = Types.Lock;
    type UUID = Types.UUID;
    type YesNoChoice = Types.YesNoChoice;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type HotElem = HotMap.HotElem;
    type FullDebtInfo = Types.FullDebtInfo;
    type DebtInfo = Types.DebtInfo;

    type BuildArguments = State and {
        provider: Principal;
    };

    public func build(args: BuildArguments) : Controller.Controller {

        let { clock_parameters; vote_register; locks; deposit; presence; resonance; parameters; provider; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let clock = Clock.Clock(clock_parameters);

        let deposit_facade = PayementFacade.PayementFacade({ deposit with provider; });
        let presence_facade = PayementFacade.PayementFacade({ presence with provider; });
        let resonance_facade = PayementFacade.PayementFacade({ resonance with provider; });

        let presence_debt = DebtProcessor.DebtProcessor({
            presence with 
            payement = presence_facade;
        });

        let presence_dispenser2 = PresenceDispenser2.PresenceDispenser2({
            locks;
            parameters = presence.parameters;
            debt_processor = presence_debt;
        });
        
        let lock_scheduler = LockScheduler2.LockScheduler2({
            locks;
            on_lock_added = func(lock : Lock, ballot: YesNoBallot) { presence_dispenser2.handle_lock_added(lock, ballot); };
            on_lock_removed = func(lock : Lock, ballot: YesNoBallot) { presence_dispenser2.handle_lock_removed(lock, ballot); };
        });

        let decay_model = Decay.DecayModel(decay);

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        // TODO: this should not assume it is a yes/no ballot, but work on every type of ballot
        let hot_map = HotMap.HotMap<UUID, YesNoBallot>({
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
            key_hash = Map.thash;
            on_elem_added = func({key: UUID; value: YesNoBallot}){ 
                lock_scheduler.add({
                    id = key;
                    unlock_time = value.timestamp + Timeline.get_current(value.duration_ns);
                    ballot = value;
                }); 
            };
            // TODO: could use get history instead
            on_hot_changed = func({key: UUID; old_value: YesNoBallot; new_value: YesNoBallot}){
                lock_scheduler.update({ 
                    id = key; 
                    old_time = old_value.timestamp + Timeline.get_current(old_value.duration_ns);
                    new_time = new_value.timestamp + Timeline.get_current(new_value.duration_ns);
                    ballot = new_value;
                });
            };
        });

        // @todo: need to plug the hotmap observers
        let yes_no_controller = VoteFactory.build_yes_no({
            deposit_facade;
            decay_model;
            duration_calculator;
            hot_map;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let presence_dispenser = PresenceDispenser.PresenceDispenser({ parameters = presence.parameters });

        Controller.Controller({
            clock;
            vote_register;
            lock_scheduler;
            vote_type_controller;
            deposit_facade;
            presence_facade;
            resonance_facade;
            presence_dispenser;
            decay_model;
        });
    };

};