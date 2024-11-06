import Types              "Types";
import Controller         "Controller";
import Decay              "duration/Decay";
import DurationCalculator "duration/DurationCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import MintController     "payement/MintController";

import ICRC1              "mo:icrc1-mo/ICRC1/service";
import ICRC2              "mo:icrc2-mo/ICRC2/service";

module {

    type VoteRegister = Types.VoteRegister;
    type Duration = Types.Duration;
    type Time = Int;
    type IncidentRegister = Types.IncidentRegister;

    type BuildArguments = {
        stable_data: {
            vote_register: VoteRegister;
            deposit: {
                ledger: ICRC1.service and ICRC2.service;
                fee: Nat;
                incidents: IncidentRegister;
            };
            reward: {
                ledger: ICRC1.service and ICRC2.service;
                fee: Nat;
                incidents: IncidentRegister;
            };
            parameters: {
                nominal_lock_duration: Duration;
                decay: {
                    half_life: Duration;
                    time_init: Time;
                };
            };
        };
        provider: Principal;
    };

    public func build(args: BuildArguments) : Controller.Controller {

        let { stable_data; provider; } = args;
        let { vote_register; deposit; reward; parameters; } = stable_data;
        let { nominal_lock_duration; decay; } = parameters;

        let deposit_facade = PayementFacade.PayementFacade({ deposit with provider; });
        let reward_facade = PayementFacade.PayementFacade({ reward with provider; });

        let decay_model = Decay.DecayModel(decay);

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            deposit_facade;
            reward_facade;
            decay_model;
            duration_calculator;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let mint_controller = MintController.MintController({
            vote_register;
            reward_facade;
        });

        Controller.Controller({
            vote_register;
            vote_type_controller;
            mint_controller;
            deposit_facade;
            reward_facade;
            decay_model;
        });
    };

};