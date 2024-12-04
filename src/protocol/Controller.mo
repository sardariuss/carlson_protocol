import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import Incentives         "votes/Incentives";
import BallotUtils        "votes/BallotUtils";
import PayementFacade     "payement/PayementFacade";
import PresenceDispenser  "PresenceDispenser";
import MapUtils           "utils/Map";
import Decay              "duration/Decay";
import Timeline           "utils/Timeline";
import Clock              "utils/Clock";
import LockScheduler2     "LockScheduler2";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Int                "mo:base/Int";
import Buffer             "mo:base/Buffer";
import Option             "mo:base/Option";
import Float              "mo:base/Float";
import Time               "mo:base/Time";
import Debug              "mo:base/Debug";

module {

    type Time = Int;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type ChoiceType = Types.ChoiceType;
    type QueriedBallot = Types.QueriedBallot;
    type Account = Types.Account;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;
    type ExtendedLock = PresenceDispenser.ExtendedLock;
    type TimedData<T> = Timeline.TimedData<T>;
    type UUID = Types.UUID;
    type NewVoteResult = Types.NewVoteResult;

    type WeightParams = {
        ballot: BallotType;
        update_ballot: (BallotType) -> ();
        weight: Float;
    };

    public type NewVoteArgs = {
        vote_id: UUID;
        origin: Principal;
        type_enum: Types.VoteTypeEnum;
    };

    public type PutBallotArgs = {
        vote_id: UUID;
        ballot_id: UUID;
        choice_type: ChoiceType;
        caller: Principal;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public class Controller({
        clock: Clock.Clock;
        vote_register: VoteRegister;
        lock_scheduler: LockScheduler2.LockScheduler2;
        vote_type_controller: VoteTypeController.VoteTypeController;
        deposit_facade: PayementFacade.PayementFacade;
        presence_facade: PayementFacade.PayementFacade;
        resonance_facade: PayementFacade.PayementFacade;
        presence_dispenser: PresenceDispenser.PresenceDispenser;
        decay_model: Decay.DecayModel;
    }){

        public func new_vote(args: NewVoteArgs) : NewVoteResult {

            let { type_enum; origin; vote_id } = args;

            if (Map.has(vote_register.votes, Map.thash, vote_id)){
                return #err(#VoteAlreadyExists({vote_id}));
            };

            // Add the vote
            let vote = vote_type_controller.new_vote({
                vote_id;
                vote_type_enum = type_enum;
                date = clock.get_time();
                origin;
            });
            Map.set(vote_register.votes, Map.thash, vote_id, vote);

            // Update the by_origin map
            let by_origin = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<UUID>());
            Set.add(by_origin, Set.thash, vote_id);
            Map.set(vote_register.by_origin, Map.phash, origin, by_origin);

            #ok(vote);
        };

        public func preview_ballot(args: PutBallotArgs) : PreviewBallotResult {

            let { vote_id; ballot_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id})); };
                case(?v) { v };
            };

            let put_args = { 
                vote_type; 
                choice_type; 
                args = { 
                    ballot_id; 
                    from = { 
                        owner = caller; 
                        subaccount = from_subaccount; 
                    }; 
                    time = clock.get_time(); 
                    amount; 
                }
            };

            #ok(vote_type_controller.preview_ballot(put_args));
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { ballot_id; vote_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(?v) { v };
                case(null) { return #err(#VoteNotFound({vote_id}));  };
            };

            let from = { owner = caller; subaccount = from_subaccount; };

            let time = clock.get_time();

            let put_args = { vote_type; choice_type; args = { ballot_id; from; time; amount; } };

            let result = await* vote_type_controller.put_ballot(put_args);

            switch(result){
                case(#err(_)) {};
                case(#ok(ballot_id)) {
                    // Update the user_ballots map
                    MapUtils.putInnerSet(vote_register.user_ballots, MapUtils.acchash, from, MapUtils.tthash, (vote_id, ballot_id));
                    // Update the locked amount history
                    // TODO: Should the timeline be flexible enough to allow adding entries in the past?
                    // TODO: should get clock.get_time() instead
                    Timeline.add(vote_register.total_locked, time, Timeline.get_current(vote_register.total_locked) + amount);
                    // WATCHOUT: Need to disburse the presence until now, because the presence dispenser is not clever enough
                    // to take into account the start date of the lock
                    let _ = await* run(?time);
                };
            };

            result;
        };

        public func get_ballots(account: Account) : [QueriedBallot] {
            switch(Map.get(vote_register.user_ballots, MapUtils.acchash, account)){
                case(?ballots) { 
                    Set.toArrayMap(ballots, func((vote_id, ballot_id): (UUID, UUID)) : ?QueriedBallot =
                        Option.map(find_ballot({vote_id; ballot_id;}), func(ballot: BallotType) : QueriedBallot = 
                            { vote_id; ballot_id; ballot; }
                        )
                    );
                };
                case(null) { [] };
            };
        };

        public func run(opt_time: ?Time) : async* () {

            let time = Option.get(opt_time, clock.get_time());
            Debug.print("Running controller at time: " # debug_show(time));

            lock_scheduler.try_unlock(time);

// @todo
//            let release_attempts = Buffer.Buffer<ReleaseAttempt<BallotType>>(0);
//
//            // TODO: parallelize awaits*
//            for ((vote_id, vote_type) in Map.entries(vote_register.votes)){
//                await* vote_type_controller.try_release({ 
//                    vote_type; 
//                    time;
//                    on_release_attempt = func(attempt: ReleaseAttempt<BallotType>) {
//                        // TODO: fix this giga hack here to avoid considering the ballot that has just been added
//                        if (BallotUtils.get_timestamp(attempt.elem) == time) {
//                            Debug.print("Do not consider the ballot that has been just added!");
//                        } else {
//                            release_attempts.add(attempt);
//                        };
//                    };
//                });
//            };
//
//            presence_dispenser.dispense({
//                locks = Buffer.toArray(Buffer.map<ReleaseAttempt<BallotType>, ExtendedLock>(
//                    release_attempts,
//                    func(attempt: ReleaseAttempt<BallotType>) : ExtendedLock {
//                        to_lock(attempt, time);
//                    }
//                ));
//                time_dispense = time;
//                total_locked = vote_register.total_locked;
//            });
//
//            // TODO: parallelize awaits*
//            for ({ elem; release_time; } in release_attempts.vals()){
//                if(Option.isSome(release_time)){                    
//                    // Mint the presence
//                    let _ = await* presence_facade.send_payement({ 
//                        to = BallotUtils.get_account(elem); 
//                        amount = Int.abs(Float.toInt(BallotUtils.get_presence(elem)));
//                    });
//                    // Mint the resonance
//                    let _ = await* resonance_facade.send_payement({ 
//                        to = BallotUtils.get_account(elem); 
//                        amount = Int.abs(Float.toInt(Incentives.compute_resonance({
//                            amount = BallotUtils.get_amount(elem);
//                            dissent = BallotUtils.get_dissent(elem);
//                            consent = BallotUtils.get_consent(elem);
//                            start = BallotUtils.get_timestamp(elem);
//                            end = time;
//                        })));
//                    });
//                };
//            };
        };

        public func get_votes({origin: Principal;}) : [VoteType] {
            let vote_ids = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<UUID>());
            Set.toArrayMap(vote_ids, func(vote_id: UUID) : ?VoteType {
                Map.get(vote_register.votes, Map.thash, vote_id);
            });
        };

        public func find_vote(vote_id: UUID) : ?VoteType {
            Map.get(vote_register.votes, Map.thash, vote_id);
        };

        public func find_ballot({vote_id: UUID; ballot_id: UUID;}) : ?BallotType {
            
            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(?v) { v; };
                case(null) { return null; };
            };

            vote_type_controller.find_ballot({ vote_type; ballot_id; });
        };

        public func current_decay() : Float {
            decay_model.compute_decay(clock.get_time());
        };

        public func get_deposit_incidents() : [(Nat, Types.Incident)] {
            deposit_facade.get_incidents();
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

    };

};