import Types          "Types";
import MigrationTypes "../Types";

import Map            "mo:map/Map";
import Set            "mo:map/Set";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";

module {

  type Time          = Int;
  type State         = MigrationTypes.State;
  type ICRC1         = Types.ICRC1;
  type ICRC2         = Types.ICRC2;
  type InitArgs      = Types.InitArgs;
  type UpgradeArgs   = Types.UpgradeArgs;
  type DowngradeArgs = Types.DowngradeArgs;

    public func init(args: InitArgs) : State {

        let { deposit; reward; parameters; } = args;

        #v0_1_0({
            vote_register = { 
                var index = 0; 
                votes = Map.new<Nat, Types.VoteType>();
                by_origin = Map.new<Principal, Set.Set<Nat>>();
            };
            deposit = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(deposit.ledger));
                fee = deposit.fee;
                incidents = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
            };
            reward = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(reward.ledger));
                fee = reward.fee;
                incidents = { var index = 0; incidents = Map.new<Nat, Types.Incident>(); };
            };
            parameters = { parameters with 
                decay = {
                    half_life = parameters.ballot_half_life;
                    time_init = Time.now();
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