import { EYesNoChoice, toEnum } from "../../utils/conversions/yesnochoice";
import { formatDuration } from "../../utils/conversions/duration";
import { dateToTime } from "../../utils/conversions/date";
import { get_first, get_last } from "../../utils/history";
import { backendActor } from "../../actors/BackendActor";

import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import LockChart from "../charts/LockChart";
import { BITCOIN_TOKEN_SYMBOL, DISSENT_EMOJI, BALLOT_EMOJI, LOCK_EMOJI, DURATION_EMOJI, CONSENT_EMOJI, PRESENCE_TOKEN_EMOJI, RESONANCE_TOKEN_EMOJI, PRESENCE_TOKEN_SYMBOL, RESONANCE_TOKEN_SYMBOL } from "../../constants";
import { formatBalanceE8s } from "../../utils/conversions/token";

const User = () => {
  
  const { principal } = useParams();

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const [selected, setSelected] = useState<number | null>(null);

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
      { ballots && <LockChart ballots={ballots} select_ballot={setSelected} selected={selected}/> }
      <ul>
        {
          ballots?.map((ballot, index) => (
            <li key={index} className="flex flex-col border p-2">
              <div className="flex items-center space-x-2 hover:cursor-pointer" onClick={() => setSelected(selected === index ? null : index)}>
                <span>{LOCK_EMOJI}</span>
                <span className="text-lg font-bold">{formatBalanceE8s(ballot.ballot.YES_NO.amount, BITCOIN_TOKEN_SYMBOL)}</span>
              </div>
              
              {selected === index && (
                <div className="grid grid-cols-2 gap-x-4 gap-y-2 mt-2 justify-items-center">
                  {/* Row 0: Text */}
                  <div className="col-span-2 justify-self-start">
                    { ballot.text }
                  </div>
                  {/* Row 1: Durations */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{DURATION_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Initial:</span> {formatDuration(ballot.ballot.YES_NO.timestamp + get_first(ballot.ballot.YES_NO.duration_ns).data - dateToTime(new Date(Number(ballot.ballot.YES_NO.timestamp)/ 1_000_000))) } </div>
                      <div><span className="italic text-gray-400 text-sm">Current:</span> {formatDuration(ballot.ballot.YES_NO.timestamp + get_last(ballot.ballot.YES_NO.duration_ns).data - dateToTime(new Date(Number(ballot.ballot.YES_NO.timestamp)/ 1_000_000))) } </div>
                    </div>
                  </div>
                  
                  {/* Row 2: Choices */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{BALLOT_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Yours:</span> <span className={`${toEnum(ballot.ballot.YES_NO.choice) === EYesNoChoice.Yes ? " text-green-500" : " text-red-500"}`}>
                        { toEnum(ballot.ballot.YES_NO.choice)}</span></div>
                      <div><span className="italic text-gray-400 text-sm">Current:</span> <span className={`${toEnum(ballot.ballot.YES_NO.choice) === EYesNoChoice.Yes ? " text-green-500" : " text-red-500"}`}>
                        { toEnum(ballot.ballot.YES_NO.choice)}</span></div>
                    </div>
                  </div>
                  
                  {/* Row 3: Tokens */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{PRESENCE_TOKEN_EMOJI}</span>
                    <div><span className="italic text-gray-400 text-sm">Accumulated:</span> { formatBalanceE8s(BigInt(Math.floor(get_last(ballot.ballot.YES_NO.presence).data)), PRESENCE_TOKEN_SYMBOL) }</div>
                  </div>
                  
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{RESONANCE_TOKEN_EMOJI}</span>
                    <div><span className="italic text-gray-400 text-sm">Predicted:</span> { formatBalanceE8s(BigInt(Math.floor(get_last(ballot.ballot.YES_NO.presence).data)), RESONANCE_TOKEN_SYMBOL) }</div>
                  </div>
                </div>
              )}
            </li>

          ))
        }
      </ul>
    </div>
  );
}

export default User;