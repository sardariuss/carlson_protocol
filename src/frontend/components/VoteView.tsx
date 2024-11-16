import { Account } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import VoteChart from "./VoteChart";
import VoteSlider from "./VoteSlider";
import { BallotInfo } from "./types";
import { get_no_votes, get_total_votes, get_votes, get_yes_votes } from "../utils/conversions/vote";

interface VoteViewProps {
  vote: SYesNoVote;
  fetchVotes: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account | undefined;
  selected: bigint | null;
  setSelected: (selected: bigint | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, fetchVotes, account, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const { consensusChoice, consensusRatio } = useMemo(() => {
    const total = get_total_votes(vote) + ballot.amount;
    if (total === 0n) {
      return { consensusChoice: undefined, consensusRatio: undefined };
    }
    const ratio = Number(get_yes_votes(vote) + (ballot.choice === EYesNoChoice.Yes ? ballot.amount : 0n)) / Number(total);
    return (ratio >= 0.5 ? { consensusChoice: EYesNoChoice.Yes, consensusRatio: ratio } : { consensusChoice: EYesNoChoice.No, consensusRatio: 1 - ratio });
  }, [vote, ballot]);

  const getTotalSide = (side: EYesNoChoice) : bigint => {
    var total_side = get_votes(vote, side);
    total_side += (ballot.choice === side ? ballot.amount : 0n);
    return total_side;
  }

  const getPercentage = (side: EYesNoChoice) => {
    const total = Number(get_total_votes(vote) + ballot.amount);
    if (total === 0) {
      throw new Error("Total number of votes is null");
    }
    return Number(getTotalSide(side)) / total * 100;
  }

  const getResult = () => {
    const total = get_total_votes(vote);
    if (total === 0n) {
      return "";
    }
    if (get_yes_votes(vote) >= get_no_votes(vote)) {
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
        {
          consensusChoice === undefined ? <></> :
          <div className={`flex flex-row items-baseline space-x-1 
              ${selected === vote.vote_id && ballot.amount > 0n ? `animate-pulse` : ``}
              ${consensusChoice === EYesNoChoice.Yes ? "text-green-500" : "text-red-500"}`}>
            <div className={`text-lg` }>{consensusChoice}</div>
            <div className={`text-sm leading-none`}>{consensusRatio?.toFixed(2)}</div>
          </div>
        }
      </div>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && account !== undefined && (
          <div className="flex flex-col space-y-2 items-center">
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
