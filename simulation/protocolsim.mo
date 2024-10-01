import Types          "../src/protocol/Types";
import SharedFacade   "../src/protocol/shared/SharedFacade";
import Factory        "../src/protocol/Factory";
import Duration       "../src/protocol/duration/Duration";
import MigrationTypes "../src/protocol/migrations/Types";
import Migrations     "../src/protocol/migrations/Migrations";

import Time           "mo:base/Time";
import Principal      "mo:base/Principal";
import Debug          "mo:base/Debug";
import Option         "mo:base/Option";

shared({ caller = admin }) actor class ProtocolSim(args: MigrationTypes.Args) = this {

    // STABLE MEMBER
    stable var _state: MigrationTypes.State = Migrations.install(args);
    _state := Migrations.migrate(_state, args);

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

        switch(_state){
            case(#v0_1_0(stable_data)) {
                _facade := ?SharedFacade.SharedFacade(Factory.build({
                    stable_data;
                    provider = Principal.fromActor(this);
                }));
            };
        };
    };

    // Create a new vote
    public shared({caller}) func new_vote(args: Types.NewVoteArgs) : async Types.SVoteType {
        getFacade().new_vote({ args with origin = caller; time = get_time(); });
    };

    // Get the votes of the given origin
    public query func get_votes(args: Types.GetVotesArgs) : async [Types.SVoteType] {
        getFacade().get_votes(args);
    };

    public query({caller}) func preview_ballot(args: Types.PutBallotArgs) : async Types.PreviewBallotResult {
        getFacade().preview_ballot({ args with caller; time = get_time(); });
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot(args: Types.PutBallotArgs) : async Types.PutBallotResult {
        await* getFacade().put_ballot({ args with caller; time = get_time(); });
    };

    // Unlock the tokens if the duration is reached
    // Return the number of ballots unlocked (whether the transfers succeded or not)
    public func try_refund_and_reward() : async [Types.VoteBallotId] {
        await* getFacade().try_refund_and_reward({ time = get_time() });
    };

    // Get the ballots of the given account
    public query func get_ballots(args: Types.Account) : async [Types.QueriedBallot] {
        getFacade().get_ballots(args);
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot(args: Types.VoteBallotId) : async ?Types.BallotType {
        getFacade().find_ballot(args);
    };

    // Get the failed service for the given principal
    public query func get_deposit_incidents() : async [(Nat, Types.Incident)] {
        getFacade().get_deposit_incidents();
    };

    // Get the failed rewards for the given principal
    public query func get_reward_incidents() : async [(Nat, Types.Incident)] {
        getFacade().get_reward_incidents();
    };

    func getFacade() : SharedFacade.SharedFacade {
        switch(_facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

    // SPECIFIC TO THE SCENARIO

    stable var _time_offset: Time.Time = 0;

    public shared func add_time_offset(duration: Duration.Duration) : async () {
        _time_offset := _time_offset + Duration.toTime(duration);
    };

    public shared query func get_time_offset() : async Duration.Duration {
        Duration.fromTime(_time_offset);
    };

    func get_time() : Time.Time {
        Time.now() + _time_offset;
    };

};
