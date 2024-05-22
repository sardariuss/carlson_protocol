import Types "../Types";
import VoteController "VoteController";
import Conversion "BallotConversion";

import LockScheduler "../locks/LockScheduler";
import DepositScheduler "../locks/DepositScheduler";
import YieldScheduler "../locks/YieldScheduler";
import PayementFacade "../PayementFacade";
import Decay  "../Decay";
import Reward "../Reward";

import Float "mo:base/Float";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;

    type Vote<A, B> = Types.Vote<A, B>;
    type VoteType = Types.VoteType;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoBallot = Types.Ballot<YesNoChoice>;
    type YesNoChoice = Types.YesNoChoice;

    type LockInfo = LockScheduler.LockInfo;
    type DepositInfo = DepositScheduler.DepositInfo;
    type YieldInfo = YieldScheduler.YieldInfo;

    type Time = Int;

    type YesNoVote = Vote<YesNoAggregate, YesNoChoice>;
    type YesNoController = VoteController<YesNoAggregate, YesNoChoice>;

    public class YesNoFactory({
        payement: PayementFacade.PayementFacade;
        decay_model: Decay.DecayModel;
        get_lock_duration_ns: Float -> Nat;
    }) {

        let lock_scheduler = LockScheduler.LockScheduler<YesNoBallot>({
            decay_model;
            get_lock_duration_ns;
            get_lock = func (b: YesNoBallot): LockInfo { Conversion.to_lock_info<YesNoChoice>(b); };
            update_lock = func (b: YesNoBallot, i: LockInfo): YesNoBallot { Conversion.update_lock_info<YesNoChoice>(b, i); };
        });

        let deposit_scheduler = DepositScheduler.DepositScheduler<YesNoBallot>({
            payement;
            lock_scheduler;
            get_deposit = func (b: YesNoBallot): DepositInfo { Conversion.to_deposit_info<YesNoChoice>(b); };
            update_deposit = func (b: YesNoBallot, i: DepositInfo): YesNoBallot { Conversion.update_deposit_info<YesNoChoice>(b, i); };
        });

        let yield_scheduler = YieldScheduler.YieldScheduler<YesNoBallot>({
            payement;
            deposit_scheduler;
            get_yield = func (b: YesNoBallot): YieldInfo { Conversion.to_yield_info<YesNoChoice>(b); };
            update_yield = func (b: YesNoBallot, i: YieldInfo): YesNoBallot { Conversion.update_yield_info<YesNoChoice>(b, i); };
        });

        public func buildController() : YesNoController {
            VoteController.VoteController<YesNoAggregate, YesNoChoice>({
                update_aggregate;
                compute_contest;
                compute_score;
                yield_scheduler;
            });
        };

        func update_aggregate({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time;}) : YesNoAggregate {
            switch(choice){
                case(#YES) {{
                    aggregate with 
                    total_yes = aggregate.total_yes + amount;
                    current_yes = Decay.add(aggregate.current_yes, decay_model.createDecayed(Float.fromInt(amount), time)); 
                }};
                case(#NO) {{
                    aggregate with 
                    total_no = aggregate.total_no + amount;
                    current_no = Decay.add(aggregate.current_no, decay_model.createDecayed(Float.fromInt(amount), time)); 
                }};
            };
        };

        func compute_contest({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Reward.compute_contest({ 
                choice;
                amount = Float.fromInt(amount);
                total_yes = decay_model.unwrapDecayed(aggregate.current_yes, time);
                total_no = decay_model.unwrapDecayed(aggregate.current_no, time);
            });
        };

        func compute_score({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Time}) : Float {
            Reward.compute_score({
                choice;
                amount;
                total_yes = decay_model.unwrapDecayed(aggregate.current_yes, time);
                total_no = decay_model.unwrapDecayed(aggregate.current_no, time);
            });
        };

    };

};