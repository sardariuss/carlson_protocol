import Types  "../Types";
import Timeline "../utils/Timeline";

module {

    type VoteType             = Types.VoteType;
    type Account              = Types.Account;
    type BallotType           = Types.BallotType;
    type Timeline<T>          = Types.Timeline<T>;
    type TimedData<T>         = Types.TimedData<T>;
    type Time                 = Int;

    // TODO: it would probably be clever to put the typed choice outside of the BallotInfo type
    // to avoid all these getters and setters

    public func get_account(ballot: BallotType): Account {
        switch(ballot){
            case(#YES_NO(b)) { b.from; };
        };
    };

    public func get_timestamp(ballot: BallotType): Time {
        switch(ballot){
            case(#YES_NO(b)) { b.timestamp; };
        };
    };

    public func get_presence(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { Timeline.get_current(b.presence); };
        };
    };

    public func get_amount(ballot: BallotType): Nat {
        switch(ballot){
            case(#YES_NO(b)) { b.amount; };
        };
    };

    public func get_dissent(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { b.dissent; };
        };
    };

    public func get_consent(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { Timeline.get_current(b.consent); };
        };
    };

    public func accumulate_presence(ballot: BallotType, presence: Float, time: Time): BallotType {
        switch(ballot){
            case(#YES_NO(b)) { 
                Timeline.add(b.presence, time, Timeline.get_current(b.consent) + presence);
                #YES_NO(b); 
            };
        };
    };

};