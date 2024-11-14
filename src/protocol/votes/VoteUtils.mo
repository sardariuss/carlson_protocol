import Types  "../Types";

module {

    type VoteType             = Types.VoteType;
    type AggregateHistoryType = Types.AggregateHistoryType;
    type Account              = Types.Account;
    type BallotType           = Types.BallotType;
    type Time                 = Int;

    // TODO: it would probably be clever to put the typed choice outside of the BallotInfo type
    // to avoid all these getters and setters

    public func get_account(ballot: BallotType): Account {
        switch(ballot){
            case(#YES_NO(b)) { b.from; };
        };
    };

    public func get_presence(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { b.presence; };
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
            case(#YES_NO(b)) { b.consent; };
        };
    };

    public func get_timestamp(ballot: BallotType): Time {
        switch(ballot){
            case(#YES_NO(b)) { b.timestamp; };
        };
    };

    public func add_presence(ballot: BallotType, presence: Float): BallotType {
        switch(ballot){
            case(#YES_NO(b)) { #YES_NO({ b with presence = b.presence + presence }); };
        };
    };

};