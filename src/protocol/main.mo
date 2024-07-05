import Types             "Types";
import SharedFacade      "shared/SharedFacade";
import Factory           "Factory";

import Map               "mo:map/Map";
import Set               "mo:map/Set";

import Time              "mo:base/Time";
import Principal         "mo:base/Principal";
import Debug             "mo:base/Debug";
import Option            "mo:base/Option";

import ICRC1             "mo:icrc1-mo/ICRC1/service";
import ICRC2             "mo:icrc2-mo/ICRC2/service";

shared({ caller = admin }) actor class CarlsonProtocol({
    deposit_ledger: Principal;
    reward_ledger: Principal;
    parameters: {
        ballot_half_life: Types.Duration;
        nominal_lock_duration: Types.Duration;
    }}) = this {

    // STABLE MEMBERS
    stable let _stable = {
        subaccount_register = { var deposit_index = 0; };
        vote_register = { 
            var index = 0; 
            votes = Map.new<Nat, Types.VoteType>();
            by_origin = Map.new<Principal, Set.Set<Nat>>();
        };
        payement = {
            ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(deposit_ledger));
            incident_register = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
        };
        reward = {
            ledger : ICRC1.service and ICRC2.service = actor(Principal.toText(reward_ledger));
            incident_register = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
        };
        parameters = { parameters with 
            decay = {
                half_life = parameters.ballot_half_life;
                time_init = Time.now();
            };
        };
    };

    // NON-STABLE MEMBER
    var _facade : ?SharedFacade.SharedFacade = null;

    // Unfortunately the principal of the canister cannot be used at the construction of the actor
    // because of the compiler error "cannot use self before self has been defined".
    // Therefore, one need to use an init method to initialize the facade.
    public shared({caller}) func init_facade() : async () {

        if (not Principal.equal(caller, admin)) {
            Debug.trap("Only the admin can initialize the facade");
        };

        if (Option.isSome(_facade)) {
            Debug.trap("The facade is already initialized");
        };
        
        _facade := ?SharedFacade.SharedFacade(Factory.build({
            stable_data = _stable;
            provider = Principal.fromActor(this);
        }));
    };

    // Create a new vote
    public shared({caller}) func new_vote({
        type_enum: Types.VoteTypeEnum;
    }) : async Nat {
        getFacade().new_vote({ origin = caller; time = Time.now(); type_enum; });
    };

    // Get the votes of the given origin
    public query func get_votes({
        origin: Principal;
    }) : async [Types.SVoteType] {
        getFacade().get_votes({ origin });
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot({
        vote_id: Nat; 
        choice_type: Types.ChoiceType;
        from: Types.Account;
        reward_account: Types.Account;
        amount: Nat;
    }) : async Types.PutBallotResult {
        await* getFacade().put_ballot({caller; vote_id; choice_type; from; reward_account; amount; time = Time.now();});
    };

    // Unlock the tokens if the duration is reached
    // Return the number of ballots unlocked (whether the transfers succeded or not)
    public func try_refund_and_reward() : async [Types.VoteBallotId] 
    {
        await* getFacade().try_refund_and_reward({ time = Time.now() });
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot({
        vote_id: Nat; 
        ballot_id: Nat;
    }) : async ?Types.BallotType {
        getFacade().find_ballot({vote_id; ballot_id;});
    };

    // Get the failed refunds for the given principal
    public query func get_payement_incidents() : async [(Nat, Types.Incident)] {
        Map.toArray(_stable.payement.incident_register.incidents);
    };

    // Get the failed rewards for the given principal
    public query func get_reward_incidents() : async [(Nat, Types.Incident)] {
        Map.toArray(_stable.reward.incident_register.incidents);
    };

    func getFacade() : SharedFacade.SharedFacade {
        switch(_facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

};
