import Result "mo:base/Result";

import Types "migrations/Types";

module {

    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    // MIGRATION TYPES

    public type Account           = Types.Current.Account;
    public type Subaccount        = Types.Current.Subaccount;
    public type SupportedStandard = Types.Current.SupportedStandard;
    public type Value             = Types.Current.Value;
    public type Balance           = Types.Current.Balance;
    public type Timestamp         = Types.Current.Timestamp;
    public type TimeError         = Types.Current.TimeError;
    public type TxIndex           = Types.Current.TxIndex;
    public type TransferError     = Types.Current.TransferError;
    public type TransferResult    = Types.Current.TransferResult;
    public type TransferArgs      = Types.Current.TransferArgs;
    public type ICRC1             = Types.Current.ICRC1;
    public type ApproveArgs       = Types.Current.ApproveArgs;
    public type ApproveError      = Types.Current.ApproveError;
    public type TransferFromError = Types.Current.TransferFromError;
    public type TransferFromArgs  = Types.Current.TransferFromArgs;
    public type AllowanceArgs     = Types.Current.AllowanceArgs;
    public type Allowance         = Types.Current.Allowance;
    public type ICRC2             = Types.Current.ICRC2;
    public type VoteRegister      = Types.Current.VoteRegister;
    public type VoteType          = Types.Current.VoteType;
    public type YesNoAggregate    = Types.Current.YesNoAggregate;
    public type Decayed           = Types.Current.Decayed;
    public type YesNoChoice       = Types.Current.YesNoChoice;
    public type History<T>        = Types.Current.History<T>;
    public type HistoryEntry<T>   = Types.Current.HistoryEntry<T>;
    public type Vote<A, B>        = Types.Current.Vote<A, B>;
    public type BallotInfo<B>     = Types.Current.BallotInfo<B>;
    public type DepositInfo       = Types.Current.DepositInfo;
    public type DepositState      = Types.Current.DepositState;
    public type RefundState       = Types.Current.RefundState;
    public type HotInfo           = Types.Current.HotInfo;
    public type RewardState       = Types.Current.RewardState;
    public type DurationInfo      = Types.Current.DurationInfo;
    public type Ballot<B>         = Types.Current.Ballot<B>;
    public type Incident          = Types.Current.Incident;
    public type ServiceError      = Types.Current.ServiceError;
    public type IncidentRegister  = Types.Current.IncidentRegister;
    public type Duration          = Types.Current.Duration;
    public type State             = Types.Current.State;

    // CANISTER ARGS

    public type NewVoteArgs = {
        type_enum: VoteTypeEnum;
    };

    public type GetVotesArgs = {
        origin: Principal;
    };

    public type FindVoteArgs = {
        vote_id: Nat;
    };

    public type PutBallotArgs = {
        vote_id: Nat;
        choice_type: ChoiceType;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public type FindBallotArgs = {
        vote_id: Nat;
        ballot_id: Nat;
    };

    // SHARED TYPES

    public type SVoteType = {
        #YES_NO: SVote<YesNoAggregate, YesNoChoice>;
    };

    public type SVote<A, B> = {
        vote_id: Nat;
        date: Time;
        origin: Principal;
        aggregate_history: [HistoryEntry<A>];
        ballot_register: {
            index: Nat;
            map: [(Nat, Ballot<B>)];
            locks: [Nat];
        };
    };

    // CUSTOM TYPES
    
    public type DecayParameters = {
        lambda: Float;
        shift: Float;
    };

    public type LocksParams = {
        ns_per_sat: Nat;
        decay_params: DecayParameters;
    };

    public type BallotType = {
        #YES_NO: Ballot<YesNoChoice>;
    };

    public type AggregateHistoryType = {
        #YES_NO: [HistoryEntry<YesNoAggregate>];
    };

    public type ChoiceType = {
        #YES_NO: YesNoChoice;
    };

    public type VoteTypeEnum = {
        #YES_NO;
    };

    public type Service = { tx_id: Nat; } -> async* Result<Nat, Text>;

    public type VoteNotFoundError = { #VoteNotFound: { vote_id: Nat }; };
    public type TransferIncident = { #TransferIncident: { incident_id: Nat }; };
    
    public type PutBallotError = TransferFromError or VoteNotFoundError or TransferIncident;
    
    public type PutBallotResult = Result<Nat, PutBallotError>;
    
    public type PreviewBallotResult = Result<BallotType, VoteNotFoundError>;

    public type VoteId = Nat;
    public type BallotId = Nat;
    public type VoteBallotId = {
        vote_id: VoteId;
        ballot_id: BallotId;
    };

    public type QueriedBallot = VoteBallotId and { ballot: BallotType; };

    public type ReleaseAttempt<T> = {
        elem: T;
        release_time: ?Time;
        update_elem: T -> ();
    };

};