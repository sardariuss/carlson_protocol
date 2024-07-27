
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";

import { useState, useEffect } from "react";

function Grunts() {

  const INPUT_BOX_ID = "open-grunt-input";

  const { authenticated } = useAuth()
  
  const [text, setText] = useState("");

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

  return (
    <div className="flex flex-col border-x dark:border-gray-700 bg-white dark:bg-slate-900 xl:w-1/3 lg:w-2/3 md:w-2/3 sm:w-full w-full">
      {
        authenticated ?  
        <div className="flex flex-col w-full gap-y-1 mb-2">
          <div id={INPUT_BOX_ID} className={`input-box break-words w-full text-sm
            ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
            placeholder="Grunt it up" contentEditable="true">
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
            <li className="items-center" key={index}>{grunt.text}</li>
          )) : <></>
      }
      </ul>
    </div>
  );
}

export default Grunts;
