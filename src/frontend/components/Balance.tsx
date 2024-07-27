import { Account } from "@/declarations/backend/backend.did";
import { ckBtcActor } from "../actors/CkBtcActor";
import React, { useEffect } from "react";

interface BalanceProps {
  account: Account;
}

const Balance : React.FC<BalanceProps> = ({account}) => {

  const { call: refreshBalance, data: userBalance,  } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account],
  });

  // Hook to refresh balance when account changes
  useEffect(() => {
    refreshBalance([account]);
  }, [account]);

  return (
    <div>
        Balance: {userBalance?.toString()?? "0"} ICP
    </div>
  );
}

export default Balance;