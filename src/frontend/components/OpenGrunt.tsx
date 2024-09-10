
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";

import { useState, useEffect } from "react";

interface OpenGruntProps {
  fetchGrunts: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>;
}

function OpenGrunt({ fetchGrunts } : OpenGruntProps) {

  const INPUT_BOX_ID = "open-grunt-input";
  
  const [text, setText] = useState("");

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

    const listener = function (this: HTMLElement, _ : Event) {
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
    <div className="flex flex-col w-full gap-y-1 border-y dark:border-gray-700">
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
    </div>
  );
}

export default OpenGrunt;
