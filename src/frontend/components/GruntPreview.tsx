import { protocolActor } from "../actors/ProtocolActor";
import { Account } from "@/declarations/wallet/wallet.did";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useState } from "react";
import { PutBallotArgs } from "@/declarations/protocol/protocol.did";
import { formatDuration } from "../utils/conversions/duration";

interface GruntProps {
  vote_id: bigint;
  account: Account;
  choice: EYesNoChoice;
  amount: bigint;
}

// @todo: Fix yield calculation
const GruntPreview: React.FC<GruntProps> = ({ vote_id, account, choice, amount }) => {

  const [args, setArgs] = useState<PutBallotArgs>({
    vote_id,
    from: account,
    reward_account: account,
    amount,
    choice_type: { YES_NO: toCandid(choice) },
  });

  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot",
    onSuccess: (data) => {
      if (data) {
        if ('ok' in data) {
          console.log(data.ok.YES_NO.contest);
          console.log(data.ok.YES_NO.duration_ns);
        }
      }
    }
  });

  useEffect(() => {
    setArgs({
      vote_id,
      from: account,
      reward_account: account,
      amount,
      choice_type: { YES_NO: toCandid(choice) },
    });
  }, [choice, amount]);

  useEffect(() => {
    if (amount > 0) {
      refreshPreview([args]);
    }
  }, [args]);

  return (
    <div>
      {
        preview && 'ok' in preview && 
          <div className="flex flex-row w-full items-center space-x-4 justify-center">
            <span> 🔒 {"≥ " + formatDuration(preview.ok.YES_NO.duration_ns)} </span>
            <span> 🌾 {"≈ " + (preview.ok.YES_NO.contest * 1000).toFixed() } CRL/BTC/day </span>
        </div>
      }
    </div>
  );
};

export default GruntPreview;
