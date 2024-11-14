import Types "../Types";

import Map "mo:map/Map";
import Set "mo:map/Set";

module {

    public func shareVoteType(vote_type: Types.VoteType) : Types.SVoteType {
        switch(vote_type){
            case(#YES_NO(vote)) { #YES_NO(shareVote(vote)); };
        };
    };

    public func shareVote<A, B>(vote: Types.Vote<A, B>) : Types.SVote<A, B> {
        { 
            vote with 
            aggregate_history = vote.aggregate_history.entries;
            ballot_register = {
                index = vote.ballot_register.index;
                map = Map.toArray(vote.ballot_register.map);
                locks = Set.toArray(vote.ballot_register.locks);
            }
        };
    };

};