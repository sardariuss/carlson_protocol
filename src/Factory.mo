import Types "Types";
import YesNoController "votes/YesNoController";
import VoteTypeController "votes/VoteTypeController";
import Controller "Controller";
import PayementFacade "PayementFacade";
import Decay "Decay";
import LockDurationCurve "LockDurationCurve";

import ICRC1             "mo:icrc1-mo/ICRC1/service";
import ICRC2             "mo:icrc2-mo/ICRC2/service";

import Map               "mo:map/Map";

module {

    type VoteRegister = Types.VoteRegister;
    type FailedTransfer = Types.FailedTransfer;
    type Duration = Types.Duration;
    type Time = Types.Time;

    public func build({
        vote_register: VoteRegister;
        payement_args: {
            payee: Principal;
            ledger: ICRC1.service and ICRC2.service;
            failed_transfers: Map.Map<Principal, [FailedTransfer]>;
            min_deposit: Nat;
            fee: ?Nat;
        };
        reward_args: {
            payee: Principal;
            ledger: ICRC1.service and ICRC2.service;
            failed_transfers: Map.Map<Principal, [FailedTransfer]>;
            min_deposit: Nat;
            fee: ?Nat;
        };
        decay_args: {
            half_life: Duration;
            time_init: Time;
        };
        nominal_lock_duration: Duration;
        new_vote_price: Nat;
    }) : Controller.Controller {

        let payement_facade = PayementFacade.PayementFacade(payement_args);
        let reward_facade = PayementFacade.PayementFacade(reward_args);

        let decay_model = Decay.DecayModel(decay_args);
        let lock_duration_curve = LockDurationCurve.LockDurationCurve({nominal_lock_duration});

        let yes_no_controller = YesNoController.build({
            payement_facade;
            reward_facade;
            decay_model;
            get_lock_duration_ns = lock_duration_curve.get_lock_duration_ns;
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        Controller.Controller({
            vote_register;
            payement_facade;
            vote_type_controller;
            new_vote_price;
        });
    };

};