import Types "Types";

module {

    public func get_amount(ballot: Types.Choice) : Nat {
        switch(ballot){
            case(#AYE(amt)) { amt; };
            case(#NAY(amt)) { amt; };
        };
    };

}