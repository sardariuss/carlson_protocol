import { toEnum } from "../../utils/conversions/yesnochoice";
import { formatDuration } from "../../utils/conversions/duration";
import { dateToTime } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect } from "react";
import LockChart from "../LockChart";

const User = () => {
  
  const { principal } = useParams();

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const { data: ballots, call: refreshBallots } = backendActor.useQueryCall({
    functionName: "get_ballots",
    args: [{ owner: Principal.fromText(principal), subaccount: [] }],
  });

  useEffect(() => {
    refreshBallots();
  }, []);

  const totalLocked = ballots?.reduce((acc, ballot) =>
    acc + ('DEPOSITED' in ballot.ballot.YES_NO.deposit_state ? ballot.ballot.YES_NO.amount : 0n), 0n);
  // @todo: reward preview?
  
  return (
    <div>
      <div>
        {
          totalLocked? <div> Total locked: { totalLocked.toString() } sat </div> : <></>
        }
      </div>
      { ballots && <LockChart ballots={ballots} /> }
      <ul>
        {
          ballots?.map((ballot, index) => (
            <li key={index} className="flex flex-col space-x-1 space-y-1 border">
              <div className="text-lg">{ ballot.text }</div>
              <div>{ ballot.ballot.YES_NO.amount.toString() } sat</div>
              <div>{ toEnum(ballot.ballot.YES_NO.choice) }</div>
              <div>dissent: { ballot.ballot.YES_NO.dissent }</div>
              <div>Time left: { formatDuration(ballot.ballot.YES_NO.timestamp + ballot.ballot.YES_NO.duration_ns - dateToTime(new Date())) }</div>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default User;