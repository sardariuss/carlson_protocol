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
    type History<T> = Types.History<T>;
    type SHistory<T> = Types.SHistory<T>;
    type SQueriedBallot = Types.SQueriedBallot;
    type QueriedBallot = Types.QueriedBallot;

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
        let ballots = Map.map<Nat, Ballot<B>, SBallot<B>>(vote.ballot_register.map, Map.nhash, func(id: Nat, ballot: Ballot<B>) : SBallot<B> { 
            shareBallot(ballot);
        });
        {
            vote with 
            aggregate_history = shareHistory(vote.aggregate_history);
            ballot_register = {
                index = vote.ballot_register.index;
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
            consent = { entries = ballot.consent.entries; };
            presence = { entries = ballot.presence.entries; };
            duration_ns = { entries = ballot.duration_ns.entries; };
            tx_id = ballot.tx_id;
            from = ballot.from;
            deposit_state = ballot.deposit_state;
            hotness = ballot.hotness;
            decay = ballot.decay;
        };
    };

    func shareHistory<T>(history: History<T>) : SHistory<T> {
        { entries = history.entries; };
    };

};