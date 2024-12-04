import Types "../Types";

import Map "mo:map/Map";
import Set "mo:map/Set";

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
    type SQueriedBallot = Types.SQueriedBallot;
    type QueriedBallot = Types.QueriedBallot;
    type UUID = Types.UUID;
    type SDebtInfo = Types.SDebtInfo;

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

    public func shareQueriedBallot (queried_ballot: QueriedBallot) : SQueriedBallot {
        {
            queried_ballot with
            ballot = shareBallotType(queried_ballot.ballot);
        };
    };

    func shareVote<A, B>(vote: Vote<A, B>) : SVote<A, B> {
        let ballots = Map.map<UUID, Ballot<B>, SBallot<B>>(vote.ballot_register.map, Map.thash, func(id: UUID, ballot: Ballot<B>) : SBallot<B> { 
            shareBallot(ballot);
        });
        {
            vote with 
            aggregate = shareTimeline(vote.aggregate);
            ballot_register = {
                map = Map.toArray(ballots);
                locks = Set.toArray(vote.ballot_register.locks);
            }
        };
    };

    func shareBallot<B>(ballot: Ballot<B>) : SBallot<B> {
        {
            timestamp = ballot.timestamp;
            choice = ballot.choice;
            amount = ballot.amount;
            dissent = ballot.dissent;
            consent = shareTimeline(ballot.consent);
            duration_ns = shareTimeline(ballot.duration_ns);
            tx_id = ballot.tx_id;
            from = ballot.from;
            deposit_state = ballot.deposit_state;
            hotness = ballot.hotness;
            decay = ballot.decay;
            release_date = ballot.release_date;
        };
    };

    func shareTimeline<T>(history: Timeline<T>) : STimeline<T> {
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