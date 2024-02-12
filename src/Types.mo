import Map "mo:map/Map";

module {
    
    public type Duration = {
        #YEARS: Nat;
        #DAYS: Nat;
        #HOURS: Nat;
        #MINUTES: Nat;
        #SECONDS: Nat;
        #NS: Nat;
    };

    public type DecayParameters = {
        lambda: Float;
        shift: Float;
    };

    public type Account = { 
        owner : Principal; 
        subaccount : ?Blob;
    };

    public type LocksParams = {
        ns_per_sat: Nat;
        decay_params: DecayParameters;
    };

    public type TokensLock = {
        tx_id: Nat;
        from: Account;
        ballot : Ballot;
        timestamp: Int;
        time_left: Float; // Floating point to avoid accumulating rounding errors
        rates: { 
            growth: Float;
            decay: Float; 
        };
    };

    public type BallotSide = {
        #AYE;
        #NAY;
    };

    public type Ballot = {
        #AYE: Nat;
        #NAY: Nat;
    };

    public type Vote = {
        vote_id: Nat;
        statement: Text;
        total_ayes: Nat;
        total_nays: Nat;
        locks: Map.Map<Nat, TokensLock>;
    };

    public type VotesRegister = {
        var index: Nat;
        votes: Map.Map<Nat, Vote>;
    };
}