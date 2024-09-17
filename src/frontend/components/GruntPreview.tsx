import { protocolActor } from "../actors/ProtocolActor";
import { Account } from "@/declarations/wallet/wallet.did";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useState } from "react";
import { formatDuration } from "../utils/conversions/duration";
import { MINIMUM_GRUNT, TEMP_REWARD_MULTIPLIER } from "../constants";

interface GruntProps {
  vote_id: bigint;
  account: Account;
  choice: EYesNoChoice;
  amount: bigint;
}

// @todo: Fix yield calculation
const GruntPreview: React.FC<GruntProps> = ({ vote_id, account, choice, amount }) => {

  // TODO: Somehow adding the args here raises the exception "Cannot convert undefined or null to object"
  // Right now there is still an error at start but at least it's not breaking the app
  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot"
  });

  const [dailyReward, setDailyReward] = useState<number>(0);

  const getAmount = () => {
    return amount > MINIMUM_GRUNT ? amount : MINIMUM_GRUNT;
  }

  useEffect(() => {
    refreshPreview([{
      vote_id,
      from: account,
      reward_account: account,
      amount: getAmount(),
      choice_type: { YES_NO: toCandid(choice) },
    }]);
  }, [choice, amount]);

  useEffect(() => {
    if (preview && 'ok' in preview) {
      setDailyReward(preview.ok.YES_NO.dissent * TEMP_REWARD_MULTIPLIER);
    }
  }, [preview]);

  return (
    <div>
      {
        preview && 'ok' in preview && 
          <div className="flex flex-row w-full items-center space-x-4 justify-center">
            <span> 🔒 {"≥ " + formatDuration(preview.ok.YES_NO.duration_ns)} </span>
            <span> 🌾 {"≈ " + (dailyReward).toFixed() } { `CRL/BTC/day` } </span>
        </div>
      }
    </div>
  );
};

export default GruntPreview;
