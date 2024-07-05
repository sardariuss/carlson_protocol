import Types "../Types";

module {

    public func shareVoteType(vote_type: Types.VoteType) : Types.SVoteType {
        switch(vote_type){
            case(#YES_NO(vote)) { #YES_NO({ vote with aggregate = vote.aggregate; } ); };
        };
    };

    public func shareVote<A, B>(vote: Types.Vote<A, B>) : Types.SVote<A> {
        { vote with aggregate = vote.aggregate; };
    };

};