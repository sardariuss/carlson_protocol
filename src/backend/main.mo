import Map "mo:map/Map";

import Protocol "canister:protocol";

shared({ caller = admin }) actor class Backend() {

    let votes = Map.new<Nat, Text>();

    public shared func add_grunt(text: Text) : async () {

        let vote_id = await Protocol.new_vote({ type_enum = #YES_NO });

        Map.set(votes, Map.nhash, vote_id, text);
    };

};