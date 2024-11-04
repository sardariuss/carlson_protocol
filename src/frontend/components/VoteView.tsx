import { Account } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import VoteChart from "./VoteChart";
import VoteSlider from "./VoteSlider";

type BallotInfo = {
  choice: EYesNoChoice;
  amount: bigint | undefined;
};

interface VoteViewProps {
  vote: SYesNoVote;
  fetchVotes: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account | undefined;
  selected: bigint | null;
  setSelected: (selected: bigint | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, fetchVotes, account, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const getAmount = () => {
    return ballot.amount ?? 0n;
  }

  const getTotalSide = (side: EYesNoChoice) : bigint => {
    var total_side = side === EYesNoChoice.Yes ? vote.aggregate.total_yes : vote.aggregate.total_no;
    total_side += (ballot.choice === side ? getAmount() : 0n);
    return total_side;
  }

  const getPercentage = (side: EYesNoChoice) => {
    const total = Number(vote.aggregate.total_yes + vote.aggregate.total_no + getAmount());
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

  const setChoice = (choice: EYesNoChoice) => {
    setBallot({ choice, amount: getAmount() });
  }

  const setAmount = (amount: bigint | undefined) => {
    setBallot({ choice: ballot.choice, amount });
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
          <div className={selected === vote.vote_id && getAmount() > 0n ? `animate-pulse` : ``}>{getResult()}</div>
        </div>
      </div>
      <div>
        { formatDateTime(timeToDate(vote.date)) }
      </div>
      <div className="flex m-10 h-[20rem] w-[50rem]">
        <VoteChart voteId={vote.vote_id}/>
      </div>
      <VoteSlider id={vote.vote_id} disabled={false} vote={vote} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && account !== undefined && (
          <div className="flex flex-col space-y-2">
            <PutBallotPreview vote_id={vote.vote_id} choice={ballot.choice} amount={getAmount()} />
            <PutBallot 
              vote_id={vote.vote_id} 
              account={account} 
              fetchVotes={fetchVotes} 
              choice={ballot.choice} 
              setChoice={setChoice} 
              amount={ballot.amount} 
              setAmount={setAmount}
              resetVote={resetVote}
            />
          </div>
        )
      }
    </div>
  );
};

export default VoteView;
