import Types "../Types";

import Option "mo:base/Option";

module {

    type VoteType = Types.VoteType;
    type SVoteType = Types.SVoteType;
    type BallotType = Types.BallotType;
    type SBallotType = Types.SBallotType;
    type Vote<A, B> = Types.Vote<A, B>;
    type SVote<A, B> = Types.SVote<A, B>;
    type Ballot<B> = Types.Ballot<B>;
    type SBallot<B> = Types.SBallot<B>;
    type Timeline<T> = Types.Timeline<T>;
    type STimeline<T> = Types.STimeline<T>;
    type UUID = Types.UUID;
    type SDebtInfo = Types.SDebtInfo;
    type LockInfo = Types.LockInfo;
    type SLockInfo = Types.SLockInfo;

    public func shareVoteType(vote_type: VoteType) : SVoteType {
        switch(vote_type){
            case(#YES_NO(vote)) { #YES_NO(shareVote(vote)); };
        };
    };

    public func shareBallotType(ballot: BallotType) : SBallotType {
        switch(ballot){
            case(#YES_NO(ballot)) { #YES_NO(shareBallot(ballot)); };
        };
    };

    func shareVote<A, B>(vote: Vote<A, B>) : SVote<A, B> {
        {
            vote with 
            aggregate = shareTimeline(vote.aggregate);
        };
    };

    func shareBallot<B>(ballot: Ballot<B>) : SBallot<B> {
        {
            ballot_id = ballot.ballot_id;
            vote_id = ballot.vote_id;
            timestamp = ballot.timestamp;
            choice = ballot.choice;
            amount = ballot.amount;
            dissent = ballot.dissent;
            consent = shareTimeline(ballot.consent);
            ck_btc = shareDebtInfo(ballot.ck_btc);
            presence = shareDebtInfo(ballot.presence);
            resonance = shareDebtInfo(ballot.resonance);
            tx_id = ballot.tx_id;
            from = ballot.from;
            hotness = ballot.hotness;
            decay = ballot.decay;
            lock = Option.map(ballot.lock, func(lock: LockInfo) : SLockInfo {
                {
                    duration_ns = shareTimeline(lock.duration_ns);
                    release_date = lock.release_date;
                }
            });
        };
    };

    public func shareTimeline<T>(history: Timeline<T>) : STimeline<T> {
        { current = history.current; history = history.history; };
    };

    func shareDebtInfo(debt_info: Types.DebtInfo) : SDebtInfo {
        {
            amount = shareTimeline(debt_info.amount);
            owed = debt_info.owed;
            pending = debt_info.pending;
            transfers = debt_info.transfers;
        };
    };

};