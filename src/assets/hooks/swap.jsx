


import React, { createContext, useContext, useEffect, useState } from "react";
import { useAuth } from "../auth";
import { toDefaultSub } from "../utils";


const SwapContext = createContext(null);


export const useSwap = () => {
  const {
    isAuth,
    login,
    logout,
    tokenAactor,
    tokenBactor,
    principal,
    principalText,
  } = useAuth();


    const [aBalance, setABalance] = useState("0000");
    const [bBalance, setbBalance] = useState("000");


    useEffect(() => {
        console.log("sup",aBalance,aBalance)
        checkBalance()
        }, [principal, tokenAactor, tokenBactor]);


  useEffect(() => {
  
  }, []);


  const checkBalance = () =>{
    if (tokenAactor) {
      checkAbalance();
    }
    if (tokenBactor) {
      checkBbalance();
    }
  }

  const checkAbalance = async () => {
    let balance = await tokenAactor.icrc1_balance_of(
      toDefaultSub(principal)
    );
    console.log("balanceA", balance);
    setABalance(balance);
  };

  const checkBbalance = async () => {
    let balance = await tokenBactor.icrc1_balance_of(
      toDefaultSub(principal)
    );
    console.log("balance B", balance);
    setbBalance(balance);
  };


  return {
    aBalance,
    bBalance,
    checkBalance
  };
};

/**
 * @type {React.FC}
 */
export const SwapProvider = ({ children }) => {


  const swap = useSwap();

  let context = <SwapContext.Provider value={swap}>{children}</SwapContext.Provider>;
  return context;
};

export const useSlothSwap = () => useContext(SwapProvider);
