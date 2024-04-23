
export function toDefaultSub(owner, subaccount = []) {
    return { owner: owner, subaccount: subaccount };
  }
  
  export function defaultDepositIcpSwap(token, amount, fee = 3000) {
    return { token: token, amount: amount, fee: fee };
  }
  
  export function ApproveICP(spender, fee, amount) {
    return {
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: amount,
      expected_allowance: [],
      expires_at: [],
      spender: { owner: spender, subaccount: [] },
    };
  }
  
  export function defaultIcrcTransferArgs(
    to,
    transferBalance,
    fee = [],
    subaccount = [],
    from_subaccount = []
  ) {
    return {
      fee: fee,
      amount: transferBalance,
      memo: [],
      from_subaccount: from_subaccount,
      to: toDefaultSub(to, subaccount),
      created_at_time: [],
    };
  }
  
  export function formatIcrcBalance(balance, supply) {
    let supplyAMillionth = Number(supply) / 100000000;
    return (Number(balance) * supplyAMillionth) / Number(supply);
  }
  
  export function reverseFormatIcrcBalance(scaledBalance, supply) {
    let supplyAMillionth = Number(supply) / 100000000;
    let floatNumber = (Number(scaledBalance) * Number(supply)) / supplyAMillionth;
    let truncatedInt = Math.trunc(floatNumber);
    return truncatedInt;
  }



