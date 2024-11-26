import Types              "Types";
import Controller         "Controller";
import Decay              "duration/Decay";
import DurationCalculator "duration/DurationCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import PresenceDispenser  "PresenceDispenser";
import Timeline           "utils/Timeline";
import Clock              "utils/Clock";

import ICRC1              "mo:icrc1-mo/ICRC1/service";
import ICRC2              "mo:icrc2-mo/ICRC2/service";

module {

    type VoteRegister = Types.VoteRegister;
    type Duration = Types.Duration;
    type Time = Int;
    type IncidentRegister = Types.IncidentRegister;
    type State = Types.State;

    type BuildArguments = State and {
        provider: Principal;
    };

    public func build(args: BuildArguments) : Controller.Controller {

        let { clock_parameters; vote_register; deposit; presence; resonance; parameters; provider; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let clock = Clock.Clock(clock_parameters);

        let deposit_facade = PayementFacade.PayementFacade({ deposit with provider; });
        let presence_facade = PayementFacade.PayementFacade({ presence with provider; });
        let resonance_facade = PayementFacade.PayementFacade({ resonance with provider; });

        let decay_model = Decay.DecayModel(decay);

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            deposit_facade;
            decay_model;
            duration_calculator;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let presence_dispenser = PresenceDispenser.PresenceDispenser({ parameters = presence.parameters });

        Controller.Controller({
            clock;
            vote_register;
            vote_type_controller;
            deposit_facade;
            presence_facade;
            resonance_facade;
            presence_dispenser;
            decay_model;
        });
    };

};