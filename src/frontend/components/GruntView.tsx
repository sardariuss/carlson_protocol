import { Account } from "@/declarations/wallet/wallet.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import Grunt from "./Grunt";
import { YesNoChoice } from "@/declarations/protocol/protocol.did";

interface GruntViewProps {
  grunt: SYesNoVote;
  fetchGrunts: (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>
  account: Account | undefined;
  selected: bigint | null;
  setSelected: (selected: bigint | null) => void;
}

const LIMIT_DISPLAY_PERCENTAGE = 20;

const GruntView: React.FC<GruntViewProps> = ({ grunt, fetchGrunts, account, selected, setSelected } : GruntViewProps) => {

  const getPercentage = (side: YesNoChoice) => {
    const total = Number(grunt.aggregate.total_yes + grunt.aggregate.total_no);
    if (total === 0) {
      throw new Error("Total number of votes is null");
    }
    if ('YES' in side) {
      return Number(grunt.aggregate.total_yes) / total * 100;
    } else {
      return Number(grunt.aggregate.total_no) / total * 100;
    }
  }

  const getResult = () => {
    const total = grunt.aggregate.total_yes + grunt.aggregate.total_no;
    if (total === 0n) {
      return "";
    }
    if (grunt.aggregate.total_yes >= grunt.aggregate.total_no) {
      return "YES " + getPercentage({'YES' : null}).toFixed(1) + "%"
    }
    else {
      return "NO " + getPercentage({'NO' : null}).toFixed(1) + "%"
    }
  }

  return (
    <div className="flex flex-col content-center border-b dark:border-gray-700 hover:bg-slate-50 dark:hover:bg-slate-850 px-5 py-1 hover:cursor-pointer space-y-2">
      <div className="grid grid-cols-5 grid-gap-2 justify-items-center" onClick={(e) => { setSelected(selected === grunt.vote_id ? null : grunt.vote_id) }}>
        <div className="col-span-4 justify-self-start">{grunt.text}</div>
        <div className="flex flex-row space-x-1">
          <div>{getResult()}</div>
        </div>
      </div>
      {
        selected === grunt.vote_id && grunt.vote_id !== undefined && account !== undefined && (
          <div className="flex flex-col space-y-2">
            <div className="flex w-full rounded-sm overflow-hidden" style={{ height: '1rem' }}>
            {
              grunt.aggregate.total_yes > 0 &&
                <div className="bg-green-500 text-xs font-medium text-center p-0.5 leading-none text-white"
                  style={{ width: `${getPercentage({'YES' : null}) + "%"}`, height: '1rem' }}>
                  { getPercentage({'YES' : null}) > LIMIT_DISPLAY_PERCENTAGE ? (
                    <span>𝕊 {grunt.aggregate.total_yes.toString()} Yes</span>
                  ) : null}
                </div>
            }
            {
              grunt.aggregate.total_no > 0 &&    
              <div className="bg-red-500 text-xs font-medium text-center p-0.5 leading-none text-white"
                style={{ width: `${getPercentage({'NO' : null}) + "%"}`, height: '1rem' }}>
                { getPercentage({'NO' : null}) > LIMIT_DISPLAY_PERCENTAGE ? (
                  <span>𝕊 {grunt.aggregate.total_no.toString()} No</span>
                ) : null}
              </div>
            }
            </div>
            <Grunt vote_id={grunt.vote_id} account={account} fetchGrunts={fetchGrunts}/>
          </div>
        )
      }
    </div>
  );
};

export default GruntView;
