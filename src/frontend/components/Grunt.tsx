import { YesNoChoice } from "@/declarations/protocol/protocol.did";
import { protocolActor } from "../actors/ProtocolActor";
import { backendActor } from "../actors/BackendActor";
import { Account } from "@/declarations/backend/backend.did";

interface GruntProps {
  vote_id: bigint;
  account: Account;
}

const Grunt : React.FC<GruntProps> = ({vote_id, account}) => {

  const { call: grunt, loading } = protocolActor.useUpdateCall({
    functionName: 'put_ballot',
    args: [{
        vote_id,
        from: account,
        reward_account: account,
        amount: BigInt(1_000),
    }],
    onSuccess: (data) => {
      console.log(data)
    },
    onError: (error) => {
      console.error(error);
    }
  });

  return (
    <div className="flex flex-row w-full items-center">
      <button 
          className="button-simple w-36 min-w-36 h-9 justify-center items-center"
          disabled={loading}
          onClick={grunt}
      >
          Grunt Yes with 1000 sats
      </button>
      <button 
          className="button-simple w-36 min-w-36 h-9 justify-center items-center"
          disabled={loading}
          onClick={grunt}
      >
          Grunt No with 1000 sats
      </button>
    </div>
  );
    return <></>;
}

export default Grunt;
