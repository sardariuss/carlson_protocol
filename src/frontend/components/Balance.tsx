import walletIcon from '../assets/wallet.svg';
import SvgButton from "./SvgButton";
import { Account } from "@/declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useEffect } from "react";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import { useAuth } from '@ic-reactor/react';
import { walletActor } from '../actors/WalletActor';

const accountToString = (account: Account | undefined) : string =>  {
  var str = "";
  if (account !== undefined) {
    str = account.owner.toString();
    let subaccount = fromNullable(account.subaccount);
    if (subaccount !== undefined) {
      str += " " + uint8ArrayToHexString(subaccount); 
    }
  }
  return str;
}

const Balance = () => {

  const { authenticated, identity } = useAuth({});

  if (!authenticated || identity?.getPrincipal() === null) {
      return (
          <></>
      );
  }

  const { data: account } = walletActor.useQueryCall({
    functionName: 'get_account'
  });

  const { call: refreshBalance, data: balance } = walletActor.useQueryCall({
    functionName: 'get_balance'
  });

  const { call: refreshAllowance, data: allowance } = walletActor.useQueryCall({
    functionName: 'protocol_allowance'
  });

  const { call: approve, data: approveResult } = walletActor.useUpdateCall({
    functionName: 'approve_protocol',
    args: [{
      amount: BigInt(100_000_000),
      expected_allowance: [],
      expires_at: [],
    }],
    onSuccess: (data) => {
      console.log(data)
    },
    onError: (error) => {
      console.error(error);
    }
  });

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
    console.log("HELLOOO")
    refreshBalance();
    refreshAllowance();
  }, [authenticated, identity, account]);

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
    console.log("HELLOOO")
    refreshAllowance();
  }, [approveResult]);

  return (
    <div className="flex flex-row space-x-3">
      <div className="flex flex-row space-x-1">
        <div>Balance</div>
        <div>{balance?.toString() ?? "0"} satoshis </div>
      </div>
      <div className="flex flex-row space-x-1">
        <div>Allowance</div>
        <div>{allowance?.allowance.toString()?? "0"} satoshis </div>
      </div>
      <button 
        className="button-simple w-36 min-w-36 h-9 justify-center items-center"
        onClick={approve}
      >
        Approve 1 BTC
      </button>
      <SvgButton onClick={(e) => navigator.clipboard.writeText(accountToString(account))} disabled={false} hidden={false}>
        <img src={walletIcon} className="flex h-5" alt="wallet"/>
      </SvgButton>
    </div>
  );
}

export default Balance;