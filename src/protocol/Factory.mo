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
import BallotUtils        "votes/BallotUtils";

import Map                "mo:map/Map";

import Float              "mo:base/Float";
import Debug              "mo:base/Debug";

module {

    type State       = Types.State;
    type YesNoBallot = Types.YesNoBallot;
    type UUID        = Types.UUID;
    type DebtInfo    = Types.DebtInfo;

    type Time        = Int;

    public func build(args: State and { provider: Principal }) : Controller.Controller {

        let { clock_parameters; vote_register; ballot_register; lock_register; deposit; presence; resonance; parameters; provider; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let deposit_ledger = LedgerFacade.LedgerFacade({ deposit with provider; });
        let presence_ledger = LedgerFacade.LedgerFacade({ presence with provider; });
        let resonance_ledger = LedgerFacade.LedgerFacade({ resonance with provider; });

        let deposit_debt = DebtProcessor.DebtProcessor({
            deposit with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).ck_btc;
                    };
                };
            };
            ledger = deposit_ledger;
        });

        let presence_debt = DebtProcessor.DebtProcessor({
            presence with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).presence;
                    };
                };
            };
            ledger = presence_ledger;
        });

        let resonance_debt = DebtProcessor.DebtProcessor({
            resonance with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).resonance;
                    };
                };
            };
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
                    amount = Float.fromInt(ballot.amount);
                    id = ballot.ballot_id;
                    time;
                });
                resonance_debt.add_debt({ 
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

        let yes_no_controller = VoteFactory.build_yes_no({
            ballot_register;
            decay_model;
            hot_map = HotMap.HotMap();
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let clock = Clock.Clock(clock_parameters);

        Controller.Controller({
            clock;
            vote_register;
            ballot_register;
            lock_scheduler;
            vote_type_controller;
            deposit_debt;
            presence_debt;
            resonance_debt;
            decay_model;
            presence_dispenser;
        });
    };

};