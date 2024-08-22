import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";

import Protocol      "canister:protocol";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type SVoteType = ProtocolTypes.SVoteType;
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate> and {
        text: ?Text;
    };

    let _texts = Map.new<Nat, Text>();

    public shared({ caller }) func add_grunt(text: Text) : async ?SYesNoVote {
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

    public composite query func get_grunts() : async [SYesNoVote] {
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); });
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    { vote with text = Map.get<Nat, Text>(_texts, Map.nhash, vote.vote_id); };
                };
            };
        });
    };

};