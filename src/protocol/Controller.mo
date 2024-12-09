import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import DebtProcessor      "DebtProcessor";
import MapUtils           "utils/Map";
import Decay              "duration/Decay";
import Timeline           "utils/Timeline";
import Clock              "utils/Clock";
import LockScheduler      "LockScheduler";
import SharedConversions  "shared/SharedConversions";
import BallotUtils        "votes/BallotUtils";
import PresenceDispenser  "PresenceDispenser";

import Map                "mo:map/Map";
import Set                "mo:map/Set";

import Int                "mo:base/Int";
import Option             "mo:base/Option";
import Float              "mo:base/Float";
import Time               "mo:base/Time";
import Debug              "mo:base/Debug";
import Buffer             "mo:base/Buffer";

module {

    type Time = Int;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type ChoiceType = Types.ChoiceType;
    type Account = Types.Account;
    type TimedData<T> = Timeline.TimedData<T>;
    type UUID = Types.UUID;
    type NewVoteResult = Types.NewVoteResult;
    type BallotRegister = Types.BallotRegister;

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
        ballot_register: BallotRegister;
        lock_scheduler: LockScheduler.LockScheduler;
        vote_type_controller: VoteTypeController.VoteTypeController;
        deposit_debt: DebtProcessor.DebtProcessor;
        presence_debt: DebtProcessor.DebtProcessor;
        resonance_debt: DebtProcessor.DebtProcessor;
        decay_model: Decay.DecayModel;
        presence_dispenser: PresenceDispenser.PresenceDispenser;
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

            let { vote_id; choice_type; caller; from_subaccount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id})); };
                case(?v) { v };
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let ballot = vote_type_controller.preview_ballot({vote_type; choice_type; args = { args with tx_id = 0; timestamp; from; }});

            lock_scheduler.refresh_lock_duration(BallotUtils.unwrap_yes_no(ballot), timestamp);

            #ok(ballot);
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { vote_id; ballot_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id}));  };
                case(?v) { v };
            };

            switch(find_ballot(ballot_id)){
                case(?_) { return #err(#BallotAlreadyExists({ballot_id})); };
                case(null) {};
            };

            let transfer = await* deposit_debt.get_ledger().transfer_from({
                from = { owner = caller; subaccount = from_subaccount; };
                amount;
            });

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let ballot_type = vote_type_controller.put_ballot({vote_type; choice_type; args = { args with tx_id; timestamp; from; }});

            // Update the locks
            // TODO: fix the following limitation
            // Watchout, the new ballot shall be added first, otherwise the update will trap
            lock_scheduler.add(BallotUtils.unwrap_yes_no(ballot_type), timestamp);
            for (ballot in vote_type_controller.vote_ballots(vote_type)){
                lock_scheduler.update(BallotUtils.unwrap_yes_no(ballot), timestamp);
            };

            // Add the ballot to that account
            MapUtils.putInnerSet(ballot_register.by_account, MapUtils.acchash, from, Map.thash, ballot_id);

            // TODO: Ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.shareBallotType(ballot_type));
        };

        public func get_ballots(account: Account) : [BallotType] {
            let buffer = Buffer.Buffer<BallotType>(0);
            Option.iterate(Map.get(ballot_register.by_account, MapUtils.acchash, account), func(ids: Set.Set<UUID>) {
                for (id in Set.keys(ids)) {
                    Option.iterate(Map.get(ballot_register.ballots, Map.thash, id), func(ballot_type: BallotType) {
                        buffer.add(ballot_type);
                    });
                };
            }); 
            Buffer.toArray(buffer);
        };

        public func get_vote_ballots(vote_id: UUID) : [BallotType] {
            let vote = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return []; };
                case(?v) { v };
            };
            let buffer = Buffer.Buffer<BallotType>(0);
            for (ballot in vote_type_controller.vote_ballots(vote)){
                buffer.add(ballot);
            };
            Buffer.toArray(buffer);
        };

        public func run() : async* () {
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));
            lock_scheduler.try_unlock(time);
            presence_dispenser.dispense(time);

            let transfers = Buffer.Buffer<async* ()>(3);

            transfers.add(deposit_debt.transfer_owed());
            transfers.add(presence_debt.transfer_owed());
            transfers.add(resonance_debt.transfer_owed());

            for (call in transfers.vals()){
                await* call;
            };
        };

        public func get_presence_info() : Types.PresenceInfo {
            presence_dispenser.get_info();
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

        public func find_ballot(ballot_id: UUID) : ?BallotType {
            Map.get(ballot_register.ballots, Map.thash, ballot_id);
        };

        public func current_decay() : Float {
            decay_model.compute_decay(clock.get_time());
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

    };

};