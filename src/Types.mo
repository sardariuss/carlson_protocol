import Error "mo:base/Error";
import Map   "mo:map/Map";

module {

    public type Time = Int;

    // ICRC-1 TYPES

    public type Balance = Nat;

    public type Timestamp = Nat64;

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
    };

    public type Subaccount = Blob;

    public type TxIndex = Nat;

    public type TransferError = TimeError or {
            #BadFee : { expected_fee : Balance };
            #BadBurn : { min_burn_amount : Balance };
            #InsufficientFunds : { balance : Balance };
            #Duplicate : { duplicate_of : TxIndex };
            #TemporarilyUnavailable;
            #GenericError : { error_code : Nat; message : Text };
        };

    public type TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;

        /// The time at which the transaction was created.
        /// If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };

    // FROM ICRC-2 TYPES

    public type TransferFromArgs = {
        spender_subaccount : ?Blob;
        from : Account;
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    // CUSTOM TYPES
    
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

    public type Decayed = {
        #DECAYED: Float;
    };

    public type Account = { 
        owner : Principal; 
        subaccount : ?Blob;
    };

    public type LocksParams = {
        ns_per_sat: Nat;
        decay_params: DecayParameters;
    };

    public type VoteType = {
        #YES_NO: Vote<YesNoAggregate, YesNoChoice>;
    };

    public type BallotType = {
        #YES_NO: Ballot<YesNoChoice>;
    };

    public type ChoiceType = {
        #YES_NO: YesNoChoice;
    };

    public type YesNoAggregate = {
        total_yes: Nat;
        current_yes: Decayed;
        total_no: Nat;
        current_no: Decayed;
    };

    public type YesNoChoice = {
        #YES;
        #NO;
    };

    public type Vote<A, B> = {
        date: Time;
        author: Principal;
        tx_id: Nat;
        var aggregate: A;
        ballot_register: {
            var index: Nat;
            ballots: Map.Map<Nat, Ballot<B>>;
        };
    };

    public type VoteTypeEnum = {
        #YES_NO;
    };

    public type Ballot<B> = {
        timestamp: Time;
        // Ballot info
        choice: B;
        amount: Nat;
        contest: Float;
        // Deposit info
        tx_id: Nat;
        from: Account;
        subaccount: Blob;
        deposit_state: DepositState;
        // Lock info
        hotness: Float;
        decay: Float;
        // Reward info
        reward_account: Account;
        reward_state: RewardState;
    };

    public type DepositState = {
        #LOCKED: {until: Time};
        #UNLOCKED: {
            since: Time;
            transfer: {
                #PENDING;
                #FAILED: { incident_id: Nat; };
                #SUCCESS: { tx_id: Nat };
            };
        };
    };

    public type RewardState = {
        #PENDING;
        #PENDING_TRANSFER: { amount: Nat; since: Time };
        #FAILED_TRANSFER: { incident_id: Nat; };
        #TRANSFERRED: { tx_id: Nat };
    };

    public type VoteRegister = {
        var index: Nat;
        votes: Map.Map<Nat, VoteType>;
    };

    public type Service = Nat -> async* Nat;

    public type ServiceTrappedError = {
        original_transfer: {
            tx_id: TxIndex;
            args: TransferFromArgs;
        };
        error_code: Error.ErrorCode;
    };

    public type Incident = {
        #ServiceTrapped: ServiceTrappedError;
        #TransferFailed: {
            args: TransferArgs;
            error: TransferError or { #Trapped : { error_code: Error.ErrorCode; }};
        };
    };

    public type IncidentRegister = {
        var index: Nat;
        incidents: Map.Map<Nat, Incident>;
    };

    public type SubaccountType = {
        #NEW_VOTE_FEES;
        #BALLOT_DEPOSITS: { id: Nat; };
    };

};