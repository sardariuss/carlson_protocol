import Types              "Types";
import VoteTypeController "votes/VoteTypeController";
import DebtProcessor      "DebtProcessor";
import MapUtils           "utils/Map";
import Decay              "duration/Decay";
import Timeline           "utils/Timeline";
import Clock              "utils/Clock";
import LockScheduler      "LockScheduler";
import SharedConversions  "shared/SharedConversions";

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
    type QueriedBallot = Types.QueriedBallot;
    type Account = Types.Account;
    type ReleaseAttempt<T> = Types.ReleaseAttempt<T>;
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
        lock_scheduler: LockScheduler.LockScheduler;
        vote_type_controller: VoteTypeController.VoteTypeController;
        deposit_debt: DebtProcessor.DebtProcessor;
        presence_debt: DebtProcessor.DebtProcessor;
        resonance_debt: DebtProcessor.DebtProcessor;
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

            let { vote_id; choice_type; caller; from_subaccount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id})); };
                case(?v) { v };
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            // @todo: transaction ID is 0
            #ok(vote_type_controller.preview_ballot({vote_type; choice_type; args = { args with tx_id = 0; timestamp; from; }}));
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { vote_id; ballot_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id}));  };
                case(?v) { v };
            };

            switch(vote_type_controller.find_ballot({ vote_type; ballot_id; })){
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
            switch(ballot_type){
                case(#YES_NO(ballot)) { lock_scheduler.add(ballot, timestamp); };
            };

            // Update the user_ballots map
            MapUtils.putInnerSet(vote_register.user_ballots, MapUtils.acchash, from, MapUtils.tthash, (vote_id, ballot_id));

            #ok(SharedConversions.shareBallotType(ballot_type));
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

        public func run() : async* () {
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));
            lock_scheduler.try_unlock(time);

            let transfers = Buffer.Buffer<async* ()>(3);

            transfers.add(deposit_debt.transfer_owed());
            transfers.add(presence_debt.transfer_owed());
            transfers.add(resonance_debt.transfer_owed());

            for (call in transfers.vals()){
                await* call;
            };
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

        public func get_clock() : Clock.Clock {
            clock;
        };

    };

};