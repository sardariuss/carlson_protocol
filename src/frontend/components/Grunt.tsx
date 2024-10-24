import { protocolActor } from "../actors/ProtocolActor";
import { Account } from "@/declarations/wallet/wallet.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useState } from "react";
import { PutBallotArgs } from "@/declarations/protocol/protocol.did";
import { BITCOIN_TOKEN_SYMBOL, MINIMUM_GRUNT } from "../constants";
import { formatBalanceE8s, fromE8s, toE8s } from "../utils/conversions/token";

interface GruntProps {
  vote_id: bigint;
  fetchGrunts: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>;
  account: Account;
  choice: EYesNoChoice;
  setChoice: (choice: EYesNoChoice) => void;
  amount: bigint | undefined;
  setAmount: (amount: bigint | undefined) => void;
  resetGrunt: () => void;
}

const Grunt: React.FC<GruntProps> = ({ vote_id, fetchGrunts, account, choice, setChoice, amount, setAmount, resetGrunt }) => {

  const { call: grunt, loading: grunting } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
    onSuccess: () => {
      resetGrunt();
      fetchGrunts(); // TODO: This should be done in a more efficient way than querying all the grunts again
    },
    onError: (error) => {
      console.error(error);
    },
  });

  const triggerGrunt = () => {
    if (choice && amount !== undefined) {
      grunt([{
        vote_id,
        from_subaccount: [],
        amount,
        choice_type: { YES_NO: toCandid(choice) },
      }]);
    }
  };

  const isTooSmall = () : boolean => {
    return amount !== undefined ? amount === 0n || amount < MINIMUM_GRUNT : false;
  }

  return (
    <div className="flex flex-col w-full items-center space-x-4 justify-center">
      <div className="flex flex-row w-full items-center space-x-4 justify-center">
        <div>
          <div className="text-sm">Grunt</div>
        </div>
        <div className="flex items-center space-x-1">
          <input
            type="text"
            className="w-32 h-9 border border-gray-300 rounded px-2 appearance-none focus:outline-none focus:border-blue-500"
            onChange={(e) => { setAmount(toE8s(Number(e.target.value))); }}
            prefix={BITCOIN_TOKEN_SYMBOL}
          />
          <span>{BITCOIN_TOKEN_SYMBOL}</span>
        </div>
        <div>on</div>
        <div>
          <select
            className={`w-20 h-9 appearance-none border border-gray-300 rounded px-2 focus:outline-none focus:border-blue-500 ${choice === EYesNoChoice.Yes ? "text-green-500" : "text-red-500"}`}
            value={choice}
            onChange={(e) => setChoice(e.target.value as EYesNoChoice)}
            disabled={grunting}
          >
            <option className="text-green-500" value={EYesNoChoice.Yes}>Yes</option>
            <option className="text-red-500" value={EYesNoChoice.No}>No</option>
          </select>
        </div>
        <button
          className="button-simple text-sm w-36 min-w-36 h-9 justify-center items-center"
          disabled={grunting || amount === undefined || isTooSmall()}
          onClick={triggerGrunt}
        >
          Lock
        </button>
      </div>
      <div className={`${amount !== undefined && isTooSmall() ? "text-red-500" : "text-white"} text-sm`}>
        Minimum {formatBalanceE8s(MINIMUM_GRUNT, BITCOIN_TOKEN_SYMBOL)}
      </div>
    </div>
  );
};

export default Grunt;
