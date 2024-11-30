
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import VoteView from "./VoteView";
import { useState } from "react";
import NewVote from "./NewVote";

function VoteList() {

  const { authenticated } = useAuth();

  const [selected, setSelected] = useState<string | null>(null);

  const { call: fetchVotes, data: votes } = backendActor.useQueryCall({
    functionName: 'get_votes',
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
              <VoteView selected={selected} setSelected={setSelected} vote={vote} fetchVotes={fetchVotes}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default VoteList;
