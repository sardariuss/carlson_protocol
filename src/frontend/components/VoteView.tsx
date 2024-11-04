import { Account } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import VoteChart from "./VoteChart";
import VoteSlider from "./VoteSlider";
import { BallotInfo } from "./types";

interface VoteViewProps {
  vote: SYesNoVote;
  fetchVotes: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account | undefined;
  selected: bigint | null;
  setSelected: (selected: bigint | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, fetchVotes, account, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const getTotalSide = (side: EYesNoChoice) : bigint => {
    var total_side = side === EYesNoChoice.Yes ? vote.aggregate.total_yes : vote.aggregate.total_no;
    total_side += (ballot.choice === side ? ballot.amount : 0n);
    return total_side;
  }

  const getPercentage = (side: EYesNoChoice) => {
    const total = Number(vote.aggregate.total_yes + vote.aggregate.total_no + ballot.amount);
    if (total === 0) {
      throw new Error("Total number of votes is null");
    }
    return Number(getTotalSide(side)) / total * 100;
  }

  const getResult = () => {
    const total = vote.aggregate.total_yes + vote.aggregate.total_no;
    if (total === 0n) {
      return "";
    }
    if (vote.aggregate.total_yes >= vote.aggregate.total_no) {
      return "YES " + getPercentage(EYesNoChoice.Yes).toFixed(1) + "%"
    }
    else {
      return "NO " + getPercentage(EYesNoChoice.No).toFixed(1) + "%"
    }
  }

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    if (selected !== vote.vote_id) {
      resetVote();
    }
  }, [selected]);

  return (
    <div className="flex flex-col content-center border-b dark:border-gray-700 hover:bg-slate-50 dark:hover:bg-slate-850 px-5 py-1 hover:cursor-pointer space-y-2">
      <div className="grid grid-cols-5 grid-gap-2 justify-items-center" onClick={(e) => { setSelected(selected === vote.vote_id ? null : vote.vote_id) }}>
        <div className="col-span-4 justify-self-start">{vote.text}</div>
        <div className="flex flex-row space-x-1">
          <div className={selected === vote.vote_id && ballot.amount > 0n ? `animate-pulse` : ``}>{getResult()}</div>
        </div>
      </div>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && account !== undefined && (
          <div className="flex flex-col space-y-2">
            <VoteChart vote={vote} ballot={ballot}/>
            <VoteSlider id={vote.vote_id} disabled={false} vote={vote} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
            <PutBallotPreview vote_id={vote.vote_id} ballot={ballot} />
            <PutBallot 
              vote_id={vote.vote_id} 
              account={account} 
              fetchVotes={fetchVotes} 
              ballot={ballot}
              setBallot={setBallot}
              resetVote={resetVote}
            />
            { /* formatDateTime(timeToDate(vote.date)) */ }
          </div>
        )
      }
    </div>
  );
};

export default VoteView;
