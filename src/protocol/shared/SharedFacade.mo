import Types             "../Types";
import Controller        "../Controller";
import SharedConversions "SharedConversions";

import Array             "mo:base/Array";
import Option            "mo:base/Option";
import Result            "mo:base/Result";

module {

    type Time = Int;
    type VoteId = Types.VoteId;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type SVoteType = Types.SVoteType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type SPreviewBallotResult = Types.SPreviewBallotResult;
    type VoteBallotId = Types.VoteBallotId;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type Account = Types.Account;
    type QueriedBallot = Types.QueriedBallot;
    type SQueriedBallot = Types.SQueriedBallot;
    type SBallotType = Types.SBallotType;
    type VoteNotFoundError = Types.VoteNotFoundError;

    public class SharedFacade(controller: Controller.Controller) {

        public func new_vote(args: NewVoteArgs and { origin: Principal; time: Time; }) : SVoteType {
            SharedConversions.shareVoteType(controller.new_vote(args));
        };

        public func preview_ballot(args: PutBallotArgs and { caller: Principal; time: Time; }) : SPreviewBallotResult {
            Result.mapOk<BallotType, SBallotType, VoteNotFoundError>(controller.preview_ballot(args), SharedConversions.shareBallotType);
        };

        public func put_ballot(args: PutBallotArgs and { caller: Principal; time: Time; }) : async* PutBallotResult {
            await* controller.put_ballot(args);
        };

        public func run({ time: Time; }) : async* () {
            await* controller.run({time});
        };

        public func get_votes({origin: Principal;}) : [SVoteType] {
            let vote_types = controller.get_votes({origin});
            Array.map(vote_types, SharedConversions.shareVoteType);
        };

        public func find_vote({vote_id: VoteId;}) : ?SVoteType {
            Option.map(controller.find_vote(vote_id), SharedConversions.shareVoteType);
        };

        public func get_ballots(account: Account) : [SQueriedBallot] {
            Array.map(controller.get_ballots(account), SharedConversions.shareQueriedBallot);
        };

        public func find_ballot({vote_id: VoteId; ballot_id: Nat;}) : ?SBallotType {
            Option.map<BallotType, SBallotType>(controller.find_ballot({vote_id; ballot_id;}), SharedConversions.shareBallotType);
        };

        public func compute_decay(time: Time) : Float {
            controller.compute_decay(time);
        };

        public func get_deposit_incidents() : [(Nat, Types.Incident)] {
            controller.get_deposit_incidents();
        };
        
        public func get_presence_incidents() : [(Nat, Types.Incident)] {
            controller.get_presence_incidents();
        };

        public func get_resonance_incidents() : [(Nat, Types.Incident)] {
            controller.get_resonance_incidents();
        };
        
    };
};
