import Types "Types";

module {

    type Time = Int;
    type Decayed = Types.Decayed;

    public type IDecayModel = {
        compute_decay: (Time) -> Float;
    };

};