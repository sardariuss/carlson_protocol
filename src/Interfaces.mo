import Types "Types";

module {

    type Time = Types.Time;
    type Decayed = Types.Decayed;

    public type IDecayModel = {
        compute_decay: (Time) -> Float;
    };

};