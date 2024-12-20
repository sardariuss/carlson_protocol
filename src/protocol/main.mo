import Types          "Types";
import SharedFacade   "shared/SharedFacade";
import Factory        "Factory";
import MigrationTypes "migrations/Types";
import Migrations     "migrations/Migrations";

import Time           "mo:base/Time";
import Principal      "mo:base/Principal";
import Debug          "mo:base/Debug";
import Option         "mo:base/Option";
import Result         "mo:base/Result";

shared({ caller = admin }) actor class Protocol(args: MigrationTypes.Args) = this {

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
                    stable_data with provider = Principal.fromActor(this);
                }));
            };
        };
    };

    // Create a new vote
    public shared({caller}) func new_vote(args: Types.NewVoteArgs) : async Types.SNewVoteResult {
        getFacade().new_vote({ args with origin = caller; });
    };

    // Get the votes of the given origin
    public query func get_votes(args: Types.GetVotesArgs) : async [Types.SVoteType] {
        getFacade().get_votes(args);
    };

    public query func find_vote(args: Types.FindVoteArgs) : async ?Types.SVoteType {
        getFacade().find_vote(args);
    };

    public query({caller}) func preview_ballot(args: Types.PutBallotArgs) : async Types.SPreviewBallotResult {
        getFacade().preview_ballot({ args with caller; });
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot(args: Types.PutBallotArgs) : async Types.PutBallotResult {
        await* getFacade().put_ballot({ args with caller; });
    };

    // Run the protocol
    public func run() : async () {
        await* getFacade().run();
    };

    public query func get_presence_info() : async Types.SPresenceInfo {
        getFacade().get_presence_info();
    };

    // Get the ballots of the given account
    public query func get_ballots(account: Types.Account) : async [Types.SBallotType] {
        getFacade().get_ballots(account);
    };

    // Get the ballots of the given vote
    public query func get_vote_ballots(vote_id: Types.UUID) : async [Types.SBallotType] {
        getFacade().get_vote_ballots(vote_id);
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot(ballot_id: Types.UUID) : async ?Types.SBallotType {
        getFacade().find_ballot(ballot_id);
    };

    public query func current_decay() : async Float {
        getFacade().current_decay();
    };

    public shared func add_offset(duration: Types.Duration) : async Result.Result<(), Text> {
        getFacade().add_offset(duration);
    };

    public query func get_offset() : async Types.Duration {
        getFacade().get_offset();
    };

    public query func get_time() : async Time.Time {
        getFacade().get_time();
    };


    func getFacade() : SharedFacade.SharedFacade {
        switch(_facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

};
