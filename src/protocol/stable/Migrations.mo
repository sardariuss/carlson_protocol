import V0_1_0         "./00-01-00-initial/State";
import MigrationTypes "Types";

import Debug          "mo:base/Debug";

module {

    type Time  = Int;

    type Args  = MigrationTypes.Args;
    type State = MigrationTypes.State;

    // do not forget to change current migration when you add a new one
    let { init; upgrade; downgrade; } = V0_1_0;

    public func install(args: Args) : State {
        switch(args){
            case(#init(init_args)){ 
                init(init_args);
            };
            case(_){
                Debug.trap("Unexpected install args: only #init args are supported"); 
            };
        };
    };

    public func migrate(prevState: State, args: Args): State {
        var state = prevState;

        switch(args){
            case(#upgrade(upgrade_args)){ 
                Debug.print("Upgrading state to next version");
                state := upgrade(state, upgrade_args); 
            };
            case(#downgrade(downgrade_args)){ 
                Debug.print("Downgrading state to previous version");
                state := downgrade(state, downgrade_args); 
            };
            case(_){ 
                Debug.print("Migration ignored: use #upgrade or #downgrade args to effectively migrate state");
            };
        };

        state;
    };

};