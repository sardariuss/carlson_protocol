import VoteController     "VoteController";
import Incentives         "Incentives";

import Types              "../Types";
import Decay              "../duration/Decay";
import DurationCalculator "../duration/DurationCalculator";
import HotMap             "../locks/HotMap";

import Float              "mo:base/Float";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;

    type Vote<A, B> = Types.Vote<A, B>;
    type VoteType = Types.VoteType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type YesNoChoice = Types.YesNoChoice;
    type Duration = Types.Duration;
    type TimedData<T> = Types.TimedData<T>;
    type UUID = Types.UUID;

    type HotElem = HotMap.HotElem;

    type Time = Int;

    // https://www.desmos.com/calculator/8iww2wlp2t
    // TODO: these should be protocol parameters
    // Shall be greater than 0
    let INITIAL_DISSENT_ADDEND = 100.0;
    // Shall be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
    let DISSENT_STEEPNESS = 0.55;
    // Shall be between 0 and 0.25, the closer to 0 the steepest (the more the majority is rewarded)
    let CONSENT_STEEPNESS = 0.1;

    public func build_yes_no({
        decay_model: Decay.DecayModel;
        duration_calculator: DurationCalculator.IDurationCalculator;
        hot_map: HotMap.HotMap<UUID, YesNoBallot>;
    }) : VoteController<YesNoAggregate, YesNoChoice> {

        let empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };

        func update_aggregate({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time;}) : YesNoAggregate {
            switch(choice){
                case(#YES) {{
                    aggregate with 
                    total_yes = aggregate.total_yes + amount;
                    current_yes = Decay.add(aggregate.current_yes, decay_model.create_decayed(Float.fromInt(amount), time)); 
                }};
                case(#NO) {{
                    aggregate with 
                    total_no = aggregate.total_no + amount;
                    current_no = Decay.add(aggregate.current_no, decay_model.create_decayed(Float.fromInt(amount), time)); 
                }};
            };
        };

        func compute_dissent({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Incentives.compute_dissent({
                initial_addend = INITIAL_DISSENT_ADDEND;
                steepness = DISSENT_STEEPNESS;
                choice;
                amount = Float.fromInt(amount);
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };

        func compute_consent({aggregate: YesNoAggregate; choice: YesNoChoice; time: Time;}) : Float {
            Incentives.compute_consent({ 
                steepness = CONSENT_STEEPNESS;
                choice;
                total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
            });
        };
        
        VoteController.VoteController<YesNoAggregate, YesNoChoice>({
            empty_aggregate;
            update_aggregate;
            compute_dissent;
            compute_consent;
            duration_calculator;
            hot_map;
        });
    };

};