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
    public type LockInfo           = Types.Current.LockInfo;
    public type Ballot<B>          = Types.Current.Ballot<B>;
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
    public type BallotType         = Types.Current.BallotType;
    public type BallotRegister     = Types.Current.BallotRegister;

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

    public type SBallot<B> = {
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
        tx_id: Nat;
        from: Account;
        decay: Float;
        hotness: Float;
        lock: ?SLockInfo;
    };

    public type SLockInfo = {
        duration_ns: STimeline<Nat>;
        release_date: Time;
    };

    public type SVote<A, B> = {
        vote_id: UUID;
        date: Time;
        origin: Principal;
        aggregate: STimeline<A>;
    };

    public type SPresenceInfo = {
        presence_per_ns: Float;
        time_last_dispense: Time;
        ck_btc_locked: STimeline<Nat>;
    };

    // CUSTOM TYPES

    public type PresenceInfo = {
        presence_per_ns: Float;
        time_last_dispense: Time;
        ck_btc_locked: Timeline<Nat>;
    };

    public type UpdateAggregate<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Time}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; time: Time}) -> Float;

    public type BallotAggregatorOutcome<A> = {
        aggregate: {
            update: A;
        };
        ballot: {
            dissent: Float;
            consent: Float;
        };
    };
    
    public type DecayParameters = {
        lambda: Float;
        shift: Float;
    };

    public type LocksParams = {
        ns_per_sat: Nat;
        decay_params: DecayParameters;
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

    public type YesNoBallot = Ballot<YesNoChoice>;

    // RESULT/ERROR TYPES

    public type VoteNotFoundError    = { #VoteNotFound: { vote_id: UUID; }; };
    public type NewVoteError         = { #VoteAlreadyExists: { vote_id: UUID; }; };
    public type PutBallotError       = TransferFromError or VoteNotFoundError or { #BallotAlreadyExists: { ballot_id: UUID; }; };
    public type PutBallotResult      = Result<SBallotType, PutBallotError>;
    public type PreviewBallotResult  = Result<BallotType, VoteNotFoundError>;
    public type NewVoteResult        = Result<VoteType, NewVoteError>;
    public type SNewVoteResult       = Result<SVoteType, NewVoteError>;
    public type SPreviewBallotResult = Result<SBallotType, VoteNotFoundError>;

};