
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import Grunt from "./Grunt";

import { useState, useEffect } from "react";
import { walletActor } from "../actors/WalletActor";

function GruntList() {

  const INPUT_BOX_ID = "open-grunt-input";

  const { authenticated } = useAuth()
  
  const [text, setText] = useState("");

  const { data: account, call: refreshAccount } = walletActor.useQueryCall({
    functionName: 'get_account'
  });

  const { call: fetchGrunts, data: grunts } = backendActor.useQueryCall({
    functionName: 'get_grunts',
    onSuccess: (data) => {
      console.log(data)
    }
  });

  const { call: addGrunt, loading } = backendActor.useUpdateCall({
    functionName: 'add_grunt',
    args: [text],
    onSuccess: (data) => {
      console.log(data)
      fetchGrunts();
    },
    onError: (error) => {
      console.error(error);
    }
  });

  const getResult = (grunt: SYesNoVote) => {
    const total = grunt.aggregate.total_yes + grunt.aggregate.total_no;
    return total > 0 ? (grunt.aggregate.total_yes / total * BigInt(100)).toString() + "%" : "N/A";
  }

  useEffect(() => {
    
    let proposeVoteInput = document.getElementById(INPUT_BOX_ID);

    const listener = function (this: HTMLElement, event : Event) {
      setText(this.textContent ?? "");
      // see https://stackoverflow.com/a/73813273
      if (this.innerText.length === 1 && this.children.length === 1){
        this.firstChild?.remove();
      }      
    };
    
    proposeVoteInput?.addEventListener('input', listener);
    
    return () => {
      proposeVoteInput?.removeEventListener('input', listener);
    }
  }, []);

  useEffect(() => {
    refreshAccount();
  }, [authenticated]);

  return (
    <div className="flex flex-col border-x dark:border-gray-700 bg-white dark:bg-slate-900 xl:w-1/3 lg:w-2/3 md:w-2/3 sm:w-full w-full">
      {
        authenticated ?  
        <div className="flex flex-col w-full gap-y-1 mb-2">
          <div id={INPUT_BOX_ID} className={`input-box break-words w-full text-sm
            ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
            data-placeholder="Grunt it up" contentEditable="true">
          </div>
          <div className="flex flex-row space-x-2 items-center place-self-end mx-2">
            <button 
              className="button-simple w-36 min-w-36 h-9 justify-center items-center"
              disabled={loading || text.length === 0}
              onClick={addGrunt}
            >
              Open grunt
            </button>
          </div>
        </div> : <></>
      }
      <ul>
      {
        grunts !== undefined ? 
          grunts.map((grunt: SYesNoVote, index) => (
            <li className="flex flex-col content-center" key={index}>
              <div className="grid grid-cols-2 grid-gap-2">
                <div>{grunt.text}</div>
                <div>{getResult(grunt)}</div>
              </div>
              <div>{grunt.vote_id.toString()}</div>
              {
                account !== undefined && grunt.vote_id !== undefined ?
                <Grunt vote_id={grunt.vote_id} account={account}/> : <></>
              }
            </li>
          )) : <></>
      }
      </ul>
    </div>
  );
}

export default GruntList;
