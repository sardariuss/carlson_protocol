import Types              "Types";
import Controller         "Controller";
import Decay              "duration/Decay";
import DurationCalculator "duration/DurationCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import Incentives         "votes/Incentives";
import LedgerFacade       "payement/LedgerFacade";
import PresenceDispenser  "PresenceDispenser";
import LockScheduler      "LockScheduler";
import Clock              "utils/Clock";
import HotMap             "locks/HotMap";
import Timeline           "utils/Timeline";
import DebtProcessor      "DebtProcessor";

import Map                "mo:map/Map";

import Float              "mo:base/Float";

module {

    type Time = Int;
    type State = Types.State;
    type UUID = Types.UUID;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type HotElem = HotMap.HotElem;

    public func build(args: State and { provider: Principal }) : Controller.Controller {

        let { clock_parameters; vote_register; ballot_register; lock_register; deposit; presence; resonance; parameters; provider; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let deposit_ledger = LedgerFacade.LedgerFacade({ deposit with provider; });
        let presence_ledger = LedgerFacade.LedgerFacade({ presence with provider; });
        let resonance_ledger = LedgerFacade.LedgerFacade({ resonance with provider; });

        let deposit_debt = DebtProcessor.DebtProcessor({
            deposit with 
            ledger = deposit_ledger;
        });

        let presence_debt = DebtProcessor.DebtProcessor({
            presence with 
            ledger = presence_ledger;
        });

        let resonance_debt = DebtProcessor.DebtProcessor({
            resonance with 
            ledger = resonance_ledger;
        });

        let presence_dispenser = PresenceDispenser.PresenceDispenser({
            lock_register;
            parameters = presence.parameters;
            debt_processor = presence_debt;
        });

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            lock_register;
            update_lock_duration = func(ballot: YesNoBallot, time: Time) {
                let duration_ns = duration_calculator.compute_duration_ns(ballot.hotness);
                Timeline.add(ballot.duration_ns, time, duration_ns);
                ballot.release_date := ballot.timestamp + duration_ns;
            };
            about_to_add = func (_: YesNoBallot, time: Time) {
                presence_dispenser.dispense(time);
            };
            about_to_remove = func (ballot: YesNoBallot, time: Time) {
                presence_dispenser.dispense(time);
                deposit_debt.add_debt({ 
                    account = ballot.from;
                    amount = Float.fromInt(ballot.amount);
                    id = ballot.ballot_id;
                    time;
                });
                resonance_debt.add_debt({ 
                    account = ballot.from;
                    amount = Incentives.compute_resonance({ 
                        amount = ballot.amount;
                        dissent = ballot.dissent;
                        consent = Timeline.current(ballot.consent);
                        start = ballot.timestamp;
                        end = time;
                    });
                    id = ballot.ballot_id;
                    time;
                });
            };
        });

        let decay_model = Decay.DecayModel(decay);

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
            ballot_register;
            decay_model;
            duration_calculator;
            hot_map;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let clock = Clock.Clock(clock_parameters);

        Controller.Controller({
            clock;
            vote_register;
            lock_scheduler;
            vote_type_controller;
            deposit_debt;
            presence_debt;
            resonance_debt;
            decay_model;
        });
    };

};