import Types "Types";

module {

    public func get_side(ballot: Types.Ballot) : Types.BallotSide {
        let amount = switch(ballot){
            case(#AYE(amt)) { #AYE; };
            case(#NAY(amt)) { #NAY; };
        };
    };

    public func get_amount(ballot: Types.Ballot) : Nat {
        let amount = switch(ballot){
            case(#AYE(amt)) { amt; };
            case(#NAY(amt)) { amt; };
        };
    }

}