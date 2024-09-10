import { useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { Account } from "@/declarations/wallet/wallet.did";
import { YesNoChoice } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";

interface GruntProps {
  vote_id: bigint;
  fetchGrunts: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account;
}

const Grunt: React.FC<GruntProps> = ({ vote_id, fetchGrunts, account }) => {

  const [choice, setChoice] = useState<YesNoChoice | undefined>(undefined);
  const [amount, setAmount] = useState<bigint>(BigInt(0));

  const { call: grunt, loading: grunting } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
    onSuccess: (data) => {
      console.log(data);
      fetchGrunts(); // TODO: This should be done in a more efficient way than querying all the grunts again
    },
    onError: (error) => {
      console.error(error);
    },
  });

  const triggerGrunt = () => {
    if (choice && amount > BigInt(0)) {
      grunt([
        {
          vote_id,
          from: account,
          reward_account: account,
          amount,
          choice_type: { YES_NO: choice },
        },
      ]);
    }
  };

  return (
    <div className="flex flex-row w-full items-center space-x-4">
      <button
        className={`button-simple w-12 min-w-12 h-9 justify-center items-center ${
          choice && "YES" in choice ? "bg-blue-500 text-white" : "bg-gray-300 text-black"
        }`}
        disabled={grunting}
        onClick={() => setChoice({ YES: null })}
      >
        YES
      </button>
      <button
        className={`button-simple w-12 min-w-12 h-9 justify-center items-center ${
          choice && "NO" in choice ? "bg-blue-500 text-white" : "bg-gray-300 text-black"
        }`}
        disabled={grunting}
        onClick={() => setChoice({ NO: null })}
      >
        NO
      </button>
      <input
        type="number"
        className="w-24 h-9 border border-gray-300 rounded px-2"
        value={amount.toString()}
        onChange={(e) => setAmount(BigInt(e.target.value || 0))}
        disabled={grunting}
        min="0"
        placeholder="Amount"
      />
      <button
        className="button-simple w-36 min-w-36 h-9 justify-center items-center"
        disabled={grunting || amount <= BigInt(0)}
        onClick={triggerGrunt}
      >
        Grunt with {amount.toString()} sats
      </button>
    </div>
  );
};

export default Grunt;
