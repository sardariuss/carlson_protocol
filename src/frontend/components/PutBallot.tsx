import { protocolActor } from "../actors/ProtocolActor";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { Account } from "@/declarations/protocol/protocol.did";
import { BITCOIN_TOKEN_SYMBOL, MINIMUM_BALLOT_AMOUNT } from "../constants";
import { formatBalanceE8s, fromE8s, toE8s } from "../utils/conversions/token";
import { useEffect, useRef, useState } from "react";
import { BallotInfo } from "./types";

interface PutBallotProps {
  vote_id: bigint;
  fetchVotes: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>;
  account: Account;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  resetVote: () => void;
}

const PutBallot: React.FC<PutBallotProps> = ({ vote_id, fetchVotes, account, ballot, setBallot, resetVote }) => {

  const { call: putBallot, loading } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
    onSuccess: () => {
      resetVote();
      fetchVotes(); // TODO: This should be done in a more efficient way than querying all the votes again
    },
    onError: (error) => {
      console.error(error);
    },
  });

  const triggerVote = () => {
    putBallot([{
      vote_id,
      from_subaccount: [],
      amount: ballot.amount,
      choice_type: { YES_NO: toCandid(ballot.choice) },
    }]);
  };

  const isTooSmall = () : boolean => {
    return ballot.amount < MINIMUM_BALLOT_AMOUNT;
  }

  const inputRef = useRef<HTMLInputElement>(null);
  const [isActive, setIsActive] = useState(false);

  useEffect(() => {
    if (inputRef.current && !isActive) { // Only update if input is not focused, meaning that it comes from an external stimulus
      inputRef.current.value = fromE8s(ballot.amount).toString();
    }
  },
  [ballot]);

  return (
    <div className="flex flex-col w-full items-center space-x-4 justify-center">
      <div className="flex flex-row w-full items-center space-x-4 justify-center">
        <div>
          <div className="text-sm">Vote</div>
        </div>
        <div className="flex items-center space-x-1">
          <input
            ref={inputRef}
            type="text"
            onFocus={() => setIsActive(true)}
            onBlur={() => setIsActive(false)}
            className="w-32 h-9 border border-gray-300 rounded px-2 appearance-none focus:outline-none focus:border-blue-500"
            onChange={(e) => { if(isActive) { setBallot({ choice: ballot.choice, amount: toE8s(Number(e.target.value)) ?? 0n }) }} }
            prefix={BITCOIN_TOKEN_SYMBOL}
          />
          <span>{BITCOIN_TOKEN_SYMBOL}</span>
        </div>
        <div>on</div>
        <div>
          <select
            className={`w-20 h-9 appearance-none border border-gray-300 rounded px-2 focus:outline-none focus:border-blue-500 ${ballot.choice === EYesNoChoice.Yes ? "text-green-500" : "text-red-500"}`}
            value={ballot.choice}
            onChange={(e) => setBallot({ choice: e.target.value as EYesNoChoice, amount: ballot.amount })}
            disabled={loading}
          >
            <option className="text-green-500" value={EYesNoChoice.Yes}>Yes</option>
            <option className="text-red-500" value={EYesNoChoice.No}>No</option>
          </select>
        </div>
        <button
          className="button-simple text-sm w-36 min-w-36 h-9 justify-center items-center"
          disabled={loading || isTooSmall()}
          onClick={triggerVote}
        >
          Lock
        </button>
      </div>
      <div className={`${isTooSmall() ? "text-red-500" : "text-white"} text-sm`}>
        Minimum {formatBalanceE8s(MINIMUM_BALLOT_AMOUNT, BITCOIN_TOKEN_SYMBOL)}
      </div>
    </div>
  );
};

export default PutBallot;
