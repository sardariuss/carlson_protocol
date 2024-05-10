import VotePolicy     "VotePolicy";
import VoteController "VoteController";
import Types          "../Types";
import Decay          "../Decay";

import Map            "mo:map/Map";

import Float          "mo:base/Float";

module {

    type Decayed = Types.Decayed;
    type Choice = Types.Choice;
    type Time = Int;

    type Register = VoteController.Register<YesNoAggregate, YesNoBallot>;
    type UpdatePolicy = VotePolicy.UpdatePolicy<YesNoAggregate, YesNoBallot>;

    type Vote = VotePolicy.Vote<YesNoAggregate, YesNoBallot>;
    type VoteId = VotePolicy.VoteId;

    public type YesNoAggregate = {
        yes: Decayed;
        no: Decayed;
    };

    public type YesNoBallot = {
        id: Nat;
        timestamp: Time;
        voter: Principal;
        choice: Types.Choice;
        contest: Float;
    };

    public type YesNoVote = VoteController.VoteController<YesNoAggregate, YesNoBallot>;

    public func build({
        votes: Map.Map<VoteId, Vote>;
        decay_model: Decay.DecayModel;
    }) : YesNoVote {
        VoteController.VoteController({
            votes;
            empty_aggregate;
            add_to_aggregate = decayed_aggregate(decay_model);
            ballot_hash = ballot_hash();
        });
    };

    func decayed_aggregate(decay_model: Decay.DecayModel) : UpdatePolicy {
        func({
            aggregate: YesNoAggregate;
            ballot: YesNoBallot;
        }) : YesNoAggregate {
            switch(ballot.choice){
                case(#YES(amount)) { { aggregate with yes = Decay.add(aggregate.yes, decay_model.createDecayed(Float.fromInt(amount), ballot.timestamp)); } };
                case(#NO(amount)) { { aggregate with no = Decay.add(aggregate.no, decay_model.createDecayed(Float.fromInt(amount), ballot.timestamp)); } };
            };
        };
    };

    func ballot_hash() : Map.HashUtils<YesNoBallot> {
        let (hash, equal) = Map.combineHash(Map.phash, Map.nhash);
        (
            func(b: YesNoBallot) : Nat32 { 
                hash((b.voter, b.id)); 
            },
            func(b1: YesNoBallot, b2: YesNoBallot) : Bool { 
                equal((b1.voter, b1.id), (b2.voter, b2.id)); 
            }
        );
    };

    let empty_aggregate : YesNoAggregate = {
        yes = #DECAYED(0);
        no = #DECAYED(0);
    };

};