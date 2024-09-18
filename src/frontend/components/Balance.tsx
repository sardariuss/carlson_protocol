import walletIcon from '../assets/wallet.svg';
import SvgButton from "./SvgButton";
import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect } from "react";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { Principal } from '@dfinity/principal';
import { canisterId as protocolCanisterId } from "../../declarations/protocol"

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

  if (!authenticated || identity === null) {
    return (
      <></>
    );
  }

  const account : Account = {
    owner: identity?.getPrincipal(),
    subaccount: []
  };

  const { call: refreshBalance, data: balance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { call: refreshAllowance, data: allowance } = ckBtcActor.useQueryCall({
    functionName: 'icrc2_allowance',
    args: [{
      account,
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      }
    }]
  });

  const { call: approve, data: approveResult } = ckBtcActor.useUpdateCall({
    functionName: 'icrc2_approve',
    args: [{
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: BigInt(100_000_000),
      expected_allowance: [],
      expires_at: [],
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      },
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
    refreshBalance();
    refreshAllowance();
  }, [authenticated, identity]);

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
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