import Types             "../Types";
import Controller        "../Controller";
import SharedConversions "SharedConversions";

import Array             "mo:base/Array";

module {

    type Time = Int;
    type VoteId = Nat;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type SVoteType = Types.SVoteType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type VoteBallotId = Types.VoteBallotId;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type Account = Types.Account;
    type QueriedBallot = Types.QueriedBallot;

    public class SharedFacade(controller: Controller.Controller) {

        public func new_vote(args: NewVoteArgs and { origin: Principal; time: Time; }) : SVoteType {
            SharedConversions.shareVoteType(controller.new_vote(args));
        };

        public func preview_ballot(args: PutBallotArgs and { caller: Principal; time: Time; }) : PreviewBallotResult {
            controller.preview_ballot(args);
        };

        public func put_ballot(args: PutBallotArgs and { caller: Principal; time: Time; }) : async* PutBallotResult {
            await* controller.put_ballot(args);
        };

        public func try_refund_and_reward({ time: Time; }) : async* [VoteBallotId] {
            await* controller.try_refund_and_reward({ time });
        };

        public func get_votes({origin: Principal;}) : [SVoteType] {
            let vote_types = controller.get_votes({origin});
            Array.map(vote_types, SharedConversions.shareVoteType);
        };

        public func get_ballots(account: Account) : [QueriedBallot] {
            controller.get_ballots(account);
        };

        public func find_ballot({vote_id: VoteId; ballot_id: Nat;}) : ?BallotType {
            controller.find_ballot({vote_id; ballot_id;});
        };

        public func get_deposit_incidents() : [(Nat, Types.Incident)] {
            controller.get_deposit_incidents();
        };
        
        public func get_reward_incidents() : [(Nat, Types.Incident)] {
            controller.get_reward_incidents();
        };
        
    };
};
