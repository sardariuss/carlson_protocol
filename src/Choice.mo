import Types "Types";

module {

    public func get_amount(ballot: Types.Choice) : Nat {
        switch(ballot){
            case(#YES(amount)) { amount; };
            case(#NO (amount)) { amount; };
        };
    };

}