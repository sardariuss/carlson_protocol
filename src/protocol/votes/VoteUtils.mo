import Types  "../Types";
import History "../utils/History";
import Option "mo:base/Option";

module {

    type VoteType             = Types.VoteType;
    type AggregateHistoryType = Types.AggregateHistoryType;
    type Account              = Types.Account;
    type BallotType           = Types.BallotType;
    type History<T>           = Types.History<T>;
    type HistoryEntry<T>      = Types.HistoryEntry<T>;
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
            case(#YES_NO(b)) { Option.getMapped(History.get_last(b.presence), func(entry: HistoryEntry<Float>) : Float { entry.data }, 0.0); };
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
            case(#YES_NO(b)) { Option.getMapped(History.get_last(b.consent), func(entry: HistoryEntry<Float>) : Float { entry.data }, 0.0); };
        };
    };

    public func accumulate_presence(ballot: BallotType, presence: Float, time: Time): BallotType {
        switch(ballot){
            case(#YES_NO(b)) { 
                History.add(b.presence, time, Option.getMapped(
                    History.get_last(b.presence), func(entry: HistoryEntry<Float>) : Float { entry.data }, 0.0) + presence);
                #YES_NO(b); 
            };
        };
    };

};