import Types             "../Types";
import Controller        "../Controller";
import SharedConversions "SharedConversions";

import Array             "mo:base/Array";
import Option            "mo:base/Option";
import Result            "mo:base/Result";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type SVoteType = Types.SVoteType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type SPreviewBallotResult = Types.SPreviewBallotResult;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type Account = Types.Account;
    type SBallotType = Types.SBallotType;
    type VoteNotFoundError = Types.VoteNotFoundError;
    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type SNewVoteResult = Types.SNewVoteResult;
    type NewVoteError = Types.NewVoteError;

    public class SharedFacade(controller: Controller.Controller) {

        public func new_vote(args: NewVoteArgs and { origin: Principal; }) : SNewVoteResult {
            Result.mapOk<VoteType, SVoteType, NewVoteError>(controller.new_vote(args), SharedConversions.shareVoteType);
        };

        public func preview_ballot(args: PutBallotArgs and { caller: Principal; }) : SPreviewBallotResult {
            Result.mapOk<BallotType, SBallotType, VoteNotFoundError>(controller.preview_ballot(args), SharedConversions.shareBallotType);
        };

        public func put_ballot(args: PutBallotArgs and { caller: Principal; }) : async* PutBallotResult {
            await* controller.put_ballot(args);
        };

        public func run() : async* () {
            await* controller.run();
        };

        public func get_votes({origin: Principal;}) : [SVoteType] {
            let vote_types = controller.get_votes({origin});
            Array.map(vote_types, SharedConversions.shareVoteType);
        };

        public func find_vote({vote_id: UUID;}) : ?SVoteType {
            Option.map(controller.find_vote(vote_id), SharedConversions.shareVoteType);
        };

        public func get_ballots(account: Account) : [SBallotType] {
            Array.map(controller.get_ballots(account), SharedConversions.shareBallotType);
        };

        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            Option.map<BallotType, SBallotType>(controller.find_ballot(ballot_id), SharedConversions.shareBallotType);
        };

        public func current_decay() : Float {
            controller.current_decay();
        };

        public func add_offset(duration: Duration) : Result<(), Text> {
            controller.get_clock().add_offset(duration);
        };

        public func get_offset() : Duration {
            controller.get_clock().get_offset();
        };

        public func get_time() : Time {
            controller.get_clock().get_time();
        };

        
    };
};
