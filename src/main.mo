import Types             "Types";
import Controller        "Controller";
import Factory           "Factory";

import Map               "mo:map/Map";

import Time              "mo:base/Time";
import Principal         "mo:base/Principal";
import Option            "mo:base/Option";

import ICRC1             "mo:icrc1-mo/ICRC1/service";
import ICRC2             "mo:icrc2-mo/ICRC2/service";

shared({ caller = admin }) actor class CarlsonProtocol({
    deposit_ledger: Principal;
    reward_ledger: Principal;
    parameters: {
        ballot_half_life: Types.Duration;
        nominal_lock_duration: Types.Duration;
        add_ballot_min_amount: Nat;
        new_vote_min_amount: Nat;
    }}) = this {

    // STABLE MEMBERS
    stable let _failed_refunds = Map.new<Principal, [Types.FailedTransfer]>();
    stable let _failed_rewards = Map.new<Principal, [Types.FailedTransfer]>();
    stable let _deposit_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(deposit_ledger));
    stable let _reward_ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(reward_ledger));
    stable let _data = {
        register = {
            var index = 0;
            votes = Map.new<Nat, Types.VoteType>();
        };
        parameters = parameters;
    };

    // NON-STABLE MEMBER
    // @todo: review arguments
    // @todo: is a min amount really necessary? Or just check if the amount is not 0?
    let _controller = Factory.build({
        vote_register = _data.register;
        payement_args = {
            payee = Principal.fromText("aaaaa-aa"); // @todo: use principal from actor
            ledger = _deposit_ledger;
            failed_transfers = Map.new<Principal, [Types.FailedTransfer]>();
            min_deposit = _data.parameters.new_vote_min_amount;
            fee = null;
        };
        reward_args = {
            payee = Principal.fromText("aaaaa-aa"); // @todo: use principal from actor
            ledger = _reward_ledger;
            failed_transfers = Map.new<Principal, [Types.FailedTransfer]>();
            min_deposit = 0;
            fee = null;
        };
        decay_args = {
            half_life = _data.parameters.ballot_half_life;
            time_init = Time.now();
        };
        nominal_lock_duration = _data.parameters.nominal_lock_duration;
        new_vote_price = _data.parameters.new_vote_min_amount;
    });

    // Create a new vote
    public shared({caller}) func new_vote({
        from: ICRC1.Account;
        type_enum: Types.VoteTypeEnum;
    }) : async Controller.NewVoteResult 
    {
        await* _controller.new_vote({caller; from; time = Time.now(); type_enum;});
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot({
        vote_id: Nat; 
        choice_type: Types.ChoiceType;
        from: Types.Account;
        reward_account: Types.Account;
        amount: Nat;
    }) : async Controller.PutBallotResult 
    {
        await* _controller.put_ballot({caller; vote_id; choice_type; from; reward_account; amount; time = Time.now();});
    };

    // Unlock the tokens if the duration is reached
    // Return the number of ballots unlocked (whether the transfers succeded or not)
    public func try_refund_and_reward() : async [Controller.VoteBallotId] 
    {
        await* _controller.try_refund_and_reward({ time = Time.now() });
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot({
        vote_id: Nat; 
        ballot_id: Nat;
    }) : async ?Types.BallotType 
    {
        _controller.find_ballot({vote_id; ballot_id;});
    };

    // Get the failed refunds for the given principal
    public query func get_failed_refunds(principal: Principal) : async [Types.FailedTransfer] 
    {
        Option.get(Map.get(_failed_refunds, Map.phash, principal), []);
    };

    // Get the failed rewards for the given principal
    public query func get_failed_rewards(principal: Principal) : async [Types.FailedTransfer] 
    {
        Option.get(Map.get(_failed_rewards, Map.phash, principal), []);
    };

};
