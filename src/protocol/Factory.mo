import Types              "Types";
import Controller         "Controller";
import Decay              "Decay";
import TimeoutCalculator  "TimeoutCalculator";
import VoteFactory        "votes/VoteFactory";
import VoteTypeController "votes/VoteTypeController";
import PayementFacade     "payement/PayementFacade";
import SubaccountIndexer  "payement/SubaccountIndexer";

import ICRC1              "mo:icrc1-mo/ICRC1/service";
import ICRC2              "mo:icrc2-mo/ICRC2/service";

module {

    type VoteRegister = Types.VoteRegister;
    type Duration = Types.Duration;
    type Time = Types.Time;
    type IncidentRegister = Types.IncidentRegister;

    type BuildArguments = {
        stable_data: {
            subaccount_register: SubaccountIndexer.SubaccountRegister;
            vote_register: VoteRegister;
            payement: {
                ledger: ICRC1.service and ICRC2.service;
                incident_register: IncidentRegister;
            };
            reward: {
                ledger: ICRC1.service and ICRC2.service;
                incident_register: IncidentRegister;
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
        let { subaccount_register; vote_register; payement; reward; parameters; } = stable_data;
        let { nominal_lock_duration; decay; } = parameters;

        let subaccount_indexer = SubaccountIndexer.SubaccountIndexer(subaccount_register);

        let payement_facade = PayementFacade.PayementFacade({payement with provider; fee = null });
        let reward_facade = PayementFacade.PayementFacade({reward with provider; fee = null });

        let decay_model = Decay.DecayModel(decay);

        let timeout_calculator = TimeoutCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            subaccount_indexer;
            payement_facade;
            reward_facade;
            decay_model;
            timeout_calculator;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        Controller.Controller({
            vote_register;
            vote_type_controller;
        });
    };

};