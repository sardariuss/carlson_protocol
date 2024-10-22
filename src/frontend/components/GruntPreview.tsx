import { protocolActor } from "../actors/ProtocolActor";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect } from "react";
import { formatDuration } from "../utils/conversions/duration";
import { DISSENT_EMOJI, DURATION_EMOJI, MINIMUM_GRUNT } from "../constants";

interface GruntProps {
  vote_id: bigint;
  choice: EYesNoChoice;
  amount: bigint;
}

const GruntPreview: React.FC<GruntProps> = ({ vote_id, choice, amount }) => {

  // TODO: Somehow adding the args here raises the exception "Cannot convert undefined or null to object"
  // Right now there is still an error at start but at least it's not breaking the app
  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot"
  });

  const getAmount = () => {
    return amount > MINIMUM_GRUNT ? amount : MINIMUM_GRUNT;
  }

  useEffect(() => {
    refreshPreview([{
      vote_id,
      from_subaccount: [],
      amount: getAmount(),
      choice_type: { YES_NO: toCandid(choice) },
    }]);
  }, [choice, amount]);

  return (
    <div>
      {
        preview && 'ok' in preview && 
          <div className="flex flex-row w-full items-center space-x-4 justify-center">
            <span> { DURATION_EMOJI + " ≥ " + formatDuration(preview.ok.YES_NO.duration_ns)} </span>
            <span> { DISSENT_EMOJI + " " + preview.ok.YES_NO.dissent.toFixed(3) } </span>
        </div>
      }
    </div>
  );
};

export default GruntPreview;
