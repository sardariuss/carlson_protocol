import { Account } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import Grunt from "./Grunt";
import { useEffect, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import { BITCOIN_TOKEN_SYMBOL } from "../constants";
import GruntPreview from "./GruntPreview";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import VoteChart from "./VoteChart";
import { formatBalanceE8s } from "../utils/conversions/token";
import { CursorSlider } from "./CursorSlider";

const LIMIT_DISPLAY_PERCENTAGE = 20;

type BallotInfo = {
  choice: EYesNoChoice;
  amount: bigint | undefined;
};

interface GruntViewProps {
  grunt: SYesNoVote;
  fetchGrunts: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account | undefined;
  selected: bigint | null;
  setSelected: (selected: bigint | null) => void;
}

const GruntView: React.FC<GruntViewProps> = ({ grunt, fetchGrunts, account, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const getAmount = () => {
    return ballot.amount ?? 0n;
  }

  const getTotalSide = (side: EYesNoChoice) : bigint => {
    var total_side = side === EYesNoChoice.Yes ? grunt.aggregate.total_yes : grunt.aggregate.total_no;
    total_side += (ballot.choice === side ? getAmount() : 0n);
    return total_side;
  }

  const getPercentage = (side: EYesNoChoice) => {
    const total = Number(grunt.aggregate.total_yes + grunt.aggregate.total_no + getAmount());
    if (total === 0) {
      throw new Error("Total number of votes is null");
    }
    return Number(getTotalSide(side)) / total * 100;
  }

  const getResult = () => {
    const total = grunt.aggregate.total_yes + grunt.aggregate.total_no;
    if (total === 0n) {
      return "";
    }
    if (grunt.aggregate.total_yes >= grunt.aggregate.total_no) {
      return "YES " + getPercentage(EYesNoChoice.Yes).toFixed(1) + "%"
    }
    else {
      return "NO " + getPercentage(EYesNoChoice.No).toFixed(1) + "%"
    }
  }

  const resetGrunt = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  const setChoice = (choice: EYesNoChoice) => {
    setBallot({ choice, amount: getAmount() });
  }

  const setAmount = (amount: bigint | undefined) => {
    setBallot({ choice: ballot.choice, amount });
  }

  useEffect(() => {
    if (selected !== grunt.vote_id) {
      resetGrunt();
    }
  }, [selected]);

  return (
    <div className="flex flex-col content-center border-b dark:border-gray-700 hover:bg-slate-50 dark:hover:bg-slate-850 px-5 py-1 hover:cursor-pointer space-y-2">
      <div className="grid grid-cols-5 grid-gap-2 justify-items-center" onClick={(e) => { setSelected(selected === grunt.vote_id ? null : grunt.vote_id) }}>
        <div className="col-span-4 justify-self-start">{grunt.text}</div>
        <div className="flex flex-row space-x-1">
          <div className={selected === grunt.vote_id && getAmount() > 0n ? `animate-pulse` : ``}>{getResult()}</div>
        </div>
      </div>
      <div>
        { formatDateTime(timeToDate(grunt.date)) }
      </div>
      <div className="flex m-10 h-[20rem] w-[50rem]">
        <VoteChart voteId={grunt.vote_id}/>
      </div>
      <CursorSlider id={grunt.vote_id} disabled={false} grunt={grunt} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
      {
        selected === grunt.vote_id && grunt.vote_id !== undefined && account !== undefined && (
          <div className="flex flex-col space-y-2">
            <div className="flex w-full rounded-sm overflow-hidden" style={{ height: '1rem' }}>
            {
              getTotalSide(EYesNoChoice.Yes) > 0 &&
                <div className={`text-xs font-medium text-center p-0.5 leading-none text-white bg-green-500 hover:border border-green-200 ${ballot.choice === EYesNoChoice.Yes ? 'border' : ''}`}
                  style={{ width: `${getPercentage(EYesNoChoice.Yes) + "%"}`, height: '1rem' }}
                  onClick={() => setChoice(EYesNoChoice.Yes)}>
                  { getPercentage(EYesNoChoice.Yes) > LIMIT_DISPLAY_PERCENTAGE ? (
                    <span className={ballot.choice === EYesNoChoice.Yes && getAmount() > 0n ? `animate-pulse` : ``}>
                      { formatBalanceE8s(getTotalSide(EYesNoChoice.Yes), BITCOIN_TOKEN_SYMBOL)} Yes
                    </span>
                  ) : null}
                </div>
            }
            {
              getTotalSide(EYesNoChoice.No) > 0 &&    
                <div className={`text-xs font-medium text-center p-0.5 leading-none text-white bg-red-500 hover:border border-red-200 ${ballot.choice === EYesNoChoice.No ? 'border' : ''}`}
                  style={{ width: `${getPercentage(EYesNoChoice.No) + "%"}`, height: '1rem' }}
                  onClick={() => setChoice(EYesNoChoice.No)}>
                  { getPercentage(EYesNoChoice.No) > LIMIT_DISPLAY_PERCENTAGE ? (
                    <span className={ballot.choice === EYesNoChoice.No && getAmount() > 0n ? `animate-pulse` : ``}>
                      { formatBalanceE8s(getTotalSide(EYesNoChoice.No), BITCOIN_TOKEN_SYMBOL)} No
                    </span>
                  ) : null}
                </div>
            }
            </div>
            <GruntPreview vote_id={grunt.vote_id} choice={ballot.choice} amount={getAmount()} />
            <Grunt 
              vote_id={grunt.vote_id} 
              account={account} 
              fetchGrunts={fetchGrunts} 
              choice={ballot.choice} 
              setChoice={setChoice} 
              amount={ballot.amount} 
              setAmount={setAmount}
              resetGrunt={resetGrunt}
            />
          </div>
        )
      }
    </div>
  );
};

export default GruntView;
