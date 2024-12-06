import { EYesNoChoice, toEnum } from "../../utils/conversions/yesnochoice";
import { formatDuration } from "../../utils/conversions/duration";
import { dateToTime, formatDate, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import LockChart from "../charts/LockChart";
import { BITCOIN_TOKEN_SYMBOL, BALLOT_EMOJI, LOCK_EMOJI, DURATION_EMOJI, PRESENCE_TOKEN_EMOJI, RESONANCE_TOKEN_EMOJI, PRESENCE_TOKEN_SYMBOL, RESONANCE_TOKEN_SYMBOL, TIMESTAMP_EMOJI } from "../../constants";
import { formatBalanceE8s } from "../../utils/conversions/token";
import { get_current, get_first, to_number_timeline } from "../../utils/timeline";
import DurationChart from "../charts/DurationChart";
import { protocolActor } from "../../actors/ProtocolActor";
import { SBallotType } from "../../../declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";
import Balance from "../Balance";

interface VoteTextProps {
  ballot: SBallotType;
}

const VoteText = ({ ballot }: VoteTextProps) => {

  const { data: text } = backendActor.useQueryCall({
    functionName: "get_vote_text",
    args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  if (!text) {
    return <div>Invalid vote</div>;
  }

  return <span>{ fromNullable(text) || "" }</span>;
}

const User = () => {
  
  const { principal } = useParams();

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const [selected, setSelected] = useState<number>(0);

  const { data: ballots, call: refreshBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
    args: [{ owner: Principal.fromText(principal), subaccount: [] }],
  });

  //const selectedBallot = selected ? ballots?.[selected] : null;

  useEffect(() => {
    refreshBallots();
  }, []);

  const totalLocked = ballots?.reduce((acc, ballot) =>
    acc + 0n, 0n); // @todo: locked amount
  // @todo: reward preview?
  
  return (
    <div className="flex flex-col items-center w-full">
      <Balance/>
      <div>
        {
          totalLocked? <div> Total locked: { formatBalanceE8s(totalLocked, BITCOIN_TOKEN_SYMBOL) } </div> : <></>
        }
      </div>
      { ballots && <LockChart ballots={ballots} select_ballot={setSelected} selected={selected}/> }
      <ul className="">
        {
          ballots?.map((ballot, index) => (
              selected === index && (
                <li key={index} className="grid grid-cols-2 gap-x-4 gap-y-2 mt-2 justify-items-center border dark:border-gray-700 border-gray-200 p-1">
                  {/* Row 1: Text */}
                  <div className="col-span-2 justify-self-start">
                    <VoteText ballot={ballot} />
                  </div>

                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{LOCK_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Amount:</span> {formatBalanceE8s(ballot.YES_NO.amount, BITCOIN_TOKEN_SYMBOL) } </div>
                    </div>
                  </div>

                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{TIMESTAMP_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Date:</span> {formatDate(timeToDate(ballot.YES_NO.timestamp)) } </div>
                    </div>
                  </div>

                  {/* Row 2: Durations */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{DURATION_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Initial:</span> {formatDuration(ballot.YES_NO.timestamp + get_first(ballot.YES_NO.duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) } </div>
                      <div><span className="italic text-gray-400 text-sm">Current:</span> {formatDuration(ballot.YES_NO.timestamp + get_current(ballot.YES_NO.duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) } </div>
                    </div>
                  </div>
                  
                  {/* Row 3: Choices */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{BALLOT_EMOJI}</span>
                    <div>
                      <div><span className="italic text-gray-400 text-sm">Yours:</span> <span className={`${toEnum(ballot.YES_NO.choice) === EYesNoChoice.Yes ? " text-green-500" : " text-red-500"}`}>
                        { toEnum(ballot.YES_NO.choice)}</span></div>
                      <div><span className="italic text-gray-400 text-sm">Current:</span> <span className={`${toEnum(ballot.YES_NO.choice) === EYesNoChoice.Yes ? " text-green-500" : " text-red-500"}`}>
                        { toEnum(ballot.YES_NO.choice)}</span></div>
                    </div>
                  </div>
                  
                  {/* Row 4: Presence */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{PRESENCE_TOKEN_EMOJI}</span>
                    <div><span className="italic text-gray-400 text-sm">Accumulated:</span> { formatBalanceE8s(BigInt(Math.floor(get_current(ballot.YES_NO.presence.amount).data)), PRESENCE_TOKEN_SYMBOL) }</div>
                  </div>
                  
                  {/* Row 5: Resonance */}
                  <div className="flex justify-center items-center space-x-2 hover:bg-slate-800 w-full hover:cursor-pointer rounded">
                    <span>{RESONANCE_TOKEN_EMOJI}</span>
                    <div><span className="italic text-gray-400 text-sm">Forecasted:</span> { formatBalanceE8s(BigInt(Math.floor(get_current(ballot.YES_NO.resonance.amount).data)), RESONANCE_TOKEN_SYMBOL) }</div>
                  </div>

                  <div className="col-span-2 w-full flex flex-col">
                    <div>Duration</div>
                    <DurationChart duration_timeline={to_number_timeline(ballot.YES_NO.duration_ns)}/>
                  </div>
                  <div className="col-span-2 w-full flex flex-col">
                    <div>Presence</div>
                    <DurationChart duration_timeline={ballot.YES_NO.presence.amount}/>
                  </div>
                  <div className="col-span-2 w-full flex flex-col">
                    <div>Consent</div>
                    <DurationChart duration_timeline={ballot.YES_NO.consent}/>
                  </div>
                  <div className="col-span-2 w-full flex flex-col">
                    { ballot.YES_NO.ballot_id }
                  </div>
                </li>
              )
          ))
        }
      </ul>
    </div>
  );
}

export default User;