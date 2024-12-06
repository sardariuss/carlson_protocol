import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";
import Result        "mo:base/Result";

import Protocol      "canister:protocol";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SVoteType = ProtocolTypes.SVoteType;
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and {
        text: ?Text;
    };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;

    type SNewVoteResult = Result.Result<SYesNoVote, SNewVoteError>;
    type SNewVoteError = ProtocolTypes.NewVoteError or { #AnonymousCaller; };

    stable let _texts = Map.new<UUID, Text>();

    public shared({ caller }) func new_vote({text: Text; vote_id: UUID}) : async SNewVoteResult {
        if (Principal.isAnonymous(caller)){
            return #err(#AnonymousCaller);
        };
        Result.mapOk(await Protocol.new_vote({ type_enum = #YES_NO; vote_id; }), func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type) {
                case(#YES_NO(vote)) {
                    Map.set(_texts, Map.thash, vote.vote_id, text);
                    { vote with text = ?text; };
                };
            };
        });
    };

    public composite query func get_votes() : async [SYesNoVote] {
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); });
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    { vote with text = Map.get<UUID, Text>(_texts, Map.thash, vote.vote_id); };
                };
            };
        });
    };

};