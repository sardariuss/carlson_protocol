import Types              "Types";
import Controller         "Controller";
import Decay              "duration/Decay";
import DurationCalculator "duration/DurationCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import LedgerFacade       "payement/LedgerFacade";
import PresenceDispenser  "PresenceDispenser";
import LockScheduler      "LockScheduler";
import Clock              "utils/Clock";
import HotMap             "locks/HotMap";
import Timeline           "utils/Timeline";
import DebtProcessor      "DebtProcessor";

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

        let decay_model = Decay.DecayModel(decay);

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        let deposit_ledger = LedgerFacade.LedgerFacade({ deposit with provider; });
        let presence_ledger = LedgerFacade.LedgerFacade({ presence with provider; });
        let resonance_ledger = LedgerFacade.LedgerFacade({ resonance with provider; });

        let presence_debt = DebtProcessor.DebtProcessor({
            presence with 
            ledger = presence_ledger;
        });

        let presence_dispenser = PresenceDispenser.PresenceDispenser({
            locks;
            parameters = presence.parameters;
            debt_processor = presence_debt;
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            locks;
            update_lock_duration = func(ballot: YesNoBallot, time: Time) {
                let duration_ns = duration_calculator.compute_duration_ns(ballot.hotness);
                Timeline.add(ballot.duration_ns, time, duration_ns);
                ballot.release_date := ballot.timestamp + duration_ns;
            };
            about_to_add = presence_dispenser.about_to_add;
            about_to_remove = presence_dispenser.about_to_remove;
        });

        // TODO: this should not assume it is a yes/no ballot, but work on every type of ballot
        let hot_map = HotMap.HotMap<UUID, YesNoBallot>({
            decay_model;
            get_elem = func (b: YesNoBallot): HotElem { b; };
            update_hotness = func ({v: YesNoBallot; hotness: Float; time: Time}) {
                v.hotness := hotness; // Watchout: need to update the hotness first because the lock_scheduler depends on it
                lock_scheduler.update(v, time);
            };
            key_hash = Map.thash;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            decay_model;
            duration_calculator;
            hot_map;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        Controller.Controller({
            clock;
            vote_register;
            lock_scheduler;
            vote_type_controller;
            deposit_ledger;
            decay_model;
        });
    };

};