
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import GruntView from "./GruntView";

import { useEffect, useState } from "react";
import { walletActor } from "../actors/WalletActor";
import OpenGrunt from "./OpenGrunt";

function GruntList() {

  const { authenticated } = useAuth()

  const [selected, setSelected] = useState<bigint | null>(null);

  const { data: account, call: refreshAccount } = walletActor.useQueryCall({
    functionName: 'get_account'
  });

  const { call: fetchGrunts, data: grunts } = backendActor.useQueryCall({
    functionName: 'get_grunts',
    onSuccess: (data) => {
      console.log(data)
    }
  });

  useEffect(() => {
    refreshAccount();
  }, [authenticated]);

  return (
    <div className="flex flex-col border-x dark:border-gray-700 bg-white dark:bg-slate-900 xl:w-1/3 lg:w-2/3 md:w-2/3 sm:w-full w-full">
      {
        authenticated && <OpenGrunt fetchGrunts={fetchGrunts}/>
      }
      <ul>
        {
          grunts && grunts.map((grunt: SYesNoVote, index) => (
            <li key={index}>
              <GruntView selected={selected} setSelected={setSelected} grunt={grunt} fetchGrunts={fetchGrunts} account={account}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default GruntList;
