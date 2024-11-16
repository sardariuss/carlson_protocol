import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";

import Protocol      "canister:protocol";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SVoteType = ProtocolTypes.SVoteType;
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and {
        text: ?Text;
    };
    type SQueriedBallot = ProtocolTypes.SQueriedBallot and {
        text: ?Text;
    };
    type Account = ProtocolTypes.Account;

    stable let _texts = Map.new<Nat, Text>();

    public shared({ caller }) func new_vote(text: Text) : async ?SYesNoVote {
        if (Principal.isAnonymous(caller)){
            return null;
        };
        switch(await Protocol.new_vote({ type_enum = #YES_NO })){
            case(#YES_NO(vote)) {
                Map.set(_texts, Map.nhash, vote.vote_id, text); 
                ?{ vote with text = ?text; };
            };
        };
    };

    public composite query func get_votes() : async [SYesNoVote] {
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); });
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    { vote with text = Map.get<Nat, Text>(_texts, Map.nhash, vote.vote_id); };
                };
            };
        });
    };

    public composite query func get_ballots(account: Account) : async [SQueriedBallot] {
        let ballots = await Protocol.get_ballots({ owner = account.owner; subaccount = account.subaccount; });
        Array.map(ballots, func(ballot: ProtocolTypes.SQueriedBallot) : SQueriedBallot {
            { ballot with text = Map.get<Nat, Text>(_texts, Map.nhash, ballot.vote_id); };
        });
    };

};