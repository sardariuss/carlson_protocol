import Result "mo:base/Result";

import Types "migrations/Types";

module {

    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    // MIGRATION TYPES

    public type Account            = Types.Current.Account;
    public type Subaccount         = Types.Current.Subaccount;
    public type SupportedStandard  = Types.Current.SupportedStandard;
    public type Value              = Types.Current.Value;
    public type Balance            = Types.Current.Balance;
    public type Timestamp          = Types.Current.Timestamp;
    public type TimeError          = Types.Current.TimeError;
    public type TxIndex            = Types.Current.TxIndex;
    public type ICRC1              = Types.Current.ICRC1;
    public type ApproveArgs        = Types.Current.ApproveArgs;
    public type ApproveError       = Types.Current.ApproveError;
    public type TransferFromError  = Types.Current.TransferFromError;
    public type TransferFromArgs   = Types.Current.TransferFromArgs;
    public type AllowanceArgs      = Types.Current.AllowanceArgs;
    public type Allowance          = Types.Current.Allowance;
    public type ICRC2              = Types.Current.ICRC2;
    public type VoteRegister       = Types.Current.VoteRegister;
    public type VoteType           = Types.Current.VoteType;
    public type YesNoAggregate     = Types.Current.YesNoAggregate;
    public type Decayed            = Types.Current.Decayed;
    public type YesNoChoice        = Types.Current.YesNoChoice;
    public type Timeline<T>        = Types.Current.Timeline<T>;
    public type TimedData<T>       = Types.Current.TimedData<T>;
    public type Vote<A, B>         = Types.Current.Vote<A, B>;
    public type BallotInfo<B>      = Types.Current.BallotInfo<B>;
    public type DepositInfo        = Types.Current.DepositInfo;
    public type HotInfo            = Types.Current.HotInfo;
    public type DurationInfo       = Types.Current.DurationInfo;
    public type Ballot<B>          = Types.Current.Ballot<B>;
    public type ServiceError       = Types.Current.ServiceError;
    public type Duration           = Types.Current.Duration;
    public type State              = Types.Current.State;
    public type ClockParameters    = Types.Current.ClockParameters;
    public type UUID               = Types.Current.UUID;
    public type Lock               = Types.Current.Lock;
    public type LockRegister       = Types.Current.LockRegister;
    public type DebtInfo           = Types.Current.DebtInfo;
    public type Transfer           = Types.Current.Transfer;
    public type TransferResult     = Types.Current.TransferResult;
    public type PresenseParameters = Types.Current.PresenseParameters;

    // CANISTER ARGS

    public type NewVoteArgs = {
        type_enum: VoteTypeEnum;
        vote_id: UUID;
    };

    public type GetVotesArgs = {
        origin: Principal;
    };

    public type FindVoteArgs = {
        vote_id: UUID;
    };

    public type PutBallotArgs = {
        ballot_id: UUID;
        vote_id: UUID;
        choice_type: ChoiceType;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public type FindBallotArgs = {
        vote_id: UUID;
        ballot_id: UUID;
    };

    public type FullDebtInfo = DebtInfo and {
        account: Account;
    };

    // SHARED TYPES

    public type SVoteType = {
        #YES_NO: SVote<YesNoAggregate, YesNoChoice>;
    };

    public type SBallotType = {
        #YES_NO: SBallot<YesNoChoice>;
    };

    public type SDebtInfo = {
        amount: STimeline<Float>;
        owed: Float;
        pending: Nat;
        transfers: [Transfer];
    };

    public type STimeline<T> = {
        current: TimedData<T>;
        history: [TimedData<T>];
    };

    public type SBallotInfo<B> = {
        ballot_id: UUID;
        vote_id: UUID;
        timestamp: Time;
        choice: B;
        amount: Nat;
        dissent: Float;
        consent: STimeline<Float>;
        ck_btc: SDebtInfo;
        presence: SDebtInfo;
        resonance: SDebtInfo;
    };

    public type SDepositInfo = {
        tx_id: Nat;
        from: Account;
    };

    public type SHotInfo = {
        hotness: Float;
        decay: Float;
    };

    public type SDurationInfo = {
        duration_ns: STimeline<Nat>;
        release_date: Time;
    };

    public type SBallot<B> = SBallotInfo<B> and SDepositInfo and SHotInfo and SDurationInfo;

    public type SVote<A, B> = {
        vote_id: UUID;
        date: Time;
        origin: Principal;
        aggregate: STimeline<A>;
        ballot_register: {
            map: [(UUID, SBallot<B>)];
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
        #YES_NO: [TimedData<YesNoAggregate>];
    };

    public type ChoiceType = {
        #YES_NO: YesNoChoice;
    };

    public type VoteTypeEnum = {
        #YES_NO;
    };

    public type Service = { tx_id: Nat; } -> async* Result<Nat, Text>;

    public type VoteNotFoundError = { #VoteNotFound: { vote_id: UUID; }; };
    
    public type PutBallotError = TransferFromError or VoteNotFoundError or { #BallotAlreadyExists: { ballot_id: UUID; }; };
    
    public type PutBallotResult = Result<SBallotType, PutBallotError>;
    
    public type PreviewBallotResult = Result<BallotType, VoteNotFoundError>;
    public type NewVoteResult = Result<VoteType, NewVoteError>;
    public type NewVoteError = { #VoteAlreadyExists: { vote_id: UUID; }; };

    public type VoteBallotId = {
        vote_id: UUID;
        ballot_id: UUID;
    };

    public type QueriedBallot = VoteBallotId and { ballot: BallotType; };
    public type SQueriedBallot = VoteBallotId and { ballot: SBallotType; };
    public type SNewVoteResult = Result<SVoteType, NewVoteError>;
    public type SPreviewBallotResult = Result<SBallotType, VoteNotFoundError>;
    

    public type ReleaseAttempt<T> = {
        elem: T;
        release_time: ?Time;
        update_elem: T -> ();
    };

};