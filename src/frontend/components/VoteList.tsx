
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import VoteView from "./VoteView";
import { Account } from '@/declarations/protocol/protocol.did';
import { useState } from "react";
import NewVote from "./NewVote";

function VoteList() {

  const { authenticated, identity } = useAuth();

  const [selected, setSelected] = useState<bigint | null>(null);

  const account : Account | undefined = identity === null ? undefined : {
    owner: identity?.getPrincipal(),
    subaccount: []
  };

  const { call: fetchVotes, data: votes } = backendActor.useQueryCall({
    functionName: 'get_votes',
    onSuccess: (data) => {
      console.log(data)
    }
  });

  return (
    <div className="flex flex-col border-x dark:border-gray-700 bg-white dark:bg-slate-900">
      {
        authenticated && <NewVote fetchVotes={fetchVotes}/>
      }
      <ul>
        {
          votes && votes.map((vote: SYesNoVote, index) => (
            <li key={index}>
              <VoteView selected={selected} setSelected={setSelected} vote={vote} fetchVotes={fetchVotes} account={account}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default VoteList;
