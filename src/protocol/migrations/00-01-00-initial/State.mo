import Types          "Types";
import MigrationTypes "../Types";
import Duration       "../../duration/Duration";
import Timeline       "../../utils/Timeline";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";
import Float          "mo:base/Float";

module {

    type Time          = Int;
    type State         = MigrationTypes.State;
    type Account       = Types.Account;
    type ICRC1         = Types.ICRC1;
    type ICRC2         = Types.ICRC2;
    type InitArgs      = Types.InitArgs;
    type UpgradeArgs   = Types.UpgradeArgs;
    type DowngradeArgs = Types.DowngradeArgs;
    type UUID          = Types.UUID;
    type Lock          = Types.Lock;
    type DebtInfo      = Types.DebtInfo;

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { simulated; deposit; presence; resonance; parameters; } = args;
        let now = Time.now();

        #v0_1_0({
            clock_parameters = {
                var offset_ns = 0;
                mutable = simulated;
            };
            vote_register = { 
                votes = Map.new<UUID, Types.VoteType>();
                by_origin = Map.new<Principal, Set.Set<UUID>>();
                user_ballots = Map.new<Account, Set.Set<(UUID, UUID)>>();
                total_locked = Timeline.initialize(now, 0);
            };
            locks = BTree.init<Lock, ()>(?BTREE_ORDER);
            deposit = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(deposit.ledger));
                fee = deposit.fee;
                incidents = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
            };
            presence = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(presence.ledger));
                fee = presence.fee;
                debts = Map.new<UUID, DebtInfo>();
                owed = Set.new<UUID>();
                incidents = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
                parameters = {
                    presence_per_ns = Float.fromInt(presence.mint_per_day) / Float.fromInt(Duration.NS_IN_DAY);
                    var time_last_dispense = now;
                };
            };
            resonance = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(resonance.ledger));
                fee = resonance.fee;
                incidents = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
            };
            parameters = { parameters with 
                decay = {
                    half_life = parameters.ballot_half_life;
                    time_init = now;
                };
            };
        });
    };

    // From nothing to 0.1.0
    public func upgrade(_: State, _: UpgradeArgs): State {
        Debug.trap("Cannot upgrade to initial version");
    };

    // From 0.1.0 to nothing
    public func downgrade(_: State, _: DowngradeArgs): State {
        Debug.trap("Cannot downgrade from initial version");
    };

};