import { protocolActor } from "../actors/ProtocolActor";
import { toCandid } from "../utils/conversions/yesnochoice";
import { useEffect } from "react";
import { formatDuration } from "../utils/conversions/duration";
import { DISSENT_EMOJI, DURATION_EMOJI } from "../constants";
import { BallotInfo } from "./types";
import { get_current } from "../utils/timeline";

interface PutBallotPreviewProps {
  vote_id: bigint;
  ballot: BallotInfo;
}

const PutBallotPreview: React.FC<PutBallotPreviewProps> = ({ vote_id, ballot }) => {

  // TODO: Somehow adding the args here raises the exception "Cannot convert undefined or null to object"
  // Right now there is still an error at start but at least it's not breaking the app
  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot"
  });

  useEffect(() => {
    refreshPreview([{
      vote_id,
      from_subaccount: [],
      amount: ballot.amount,
      choice_type: { YES_NO: toCandid(ballot.choice) },
    }]);
  }, [ballot]);

  const formatDissent = (dissent: number) => {
    if (Number.isNaN(dissent)) {
      return "N/A";
    }
    return dissent.toFixed(3);
  }

  return (
    <div>
      {
        preview && 'ok' in preview && 
          <div className="flex flex-row w-full items-center space-x-4 justify-center">
            <span> { DURATION_EMOJI + " ≥ " + formatDuration(get_current(preview.ok.YES_NO.duration_ns).data)} </span>
            <span> { DISSENT_EMOJI + " " + formatDissent(preview.ok.YES_NO.dissent) } </span>
        </div>
      }
    </div>
  );
};

export default PutBallotPreview;
