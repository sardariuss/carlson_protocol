import { useState } from "react";
import { useAuth } from "./auth";
import { useEffect } from "react";
import {
  toDefaultSub,
  defaultIcrcTransferArgs,
  defaultDepositIcpSwap,
  reverseFormatIcrcBalance,
  formatIcrcBalance,
} from "./utils";
import { Principal } from "@dfinity/principal";
import { walletList } from "./utils/tokenList";
import { createPoolActor } from "./ic/icpswap/pool";
import { createicrc1Actor } from "./ic/icpswap/icrc1";
import { createSwapFactoryActor } from "./ic/icpswap/swapV3";
import { AccountIdentifier, SubAccount } from "@dfinity/ledger-icp";
import Mint from "./components/MintForm.jsx";

let seedTrillio = 126303531646153603164n;
let icpCanister = "ryjl3-tyaaa-aaaaa-aaaba-cai";

function Wallet({
  isAuth,
  aBalance,
  bBalance,
  withdrawA,
  withdrawB,
  principalText,
  withDrawlAddress,
  setWithdraawlAddress,
  logout,
  claim,
  identity,
}) {
  console.log("wallet");
  return (
    <>
      {!!isAuth && (
        <div>
          <button
            onClick={async () => {
              await logout();
            }}
          >
            logout
          </button>
          <button
            onClick={async () => {
              await claim();
            }}
          >
            claim
          </button>
        </div>
      )}
      <br />
      <br />
      <div className="swap-container">
        {!!!isAuth ? (
          <h1>u to sloth to sell bro?</h1>
        ) : (
          <h1>u in the clear now</h1>
        )}
      </div>
      {!!isAuth && <div className="principal-sloth">pid: {principalText}</div>}

      {isAuth && (
        <div>
          <input
            className="address-input"
            type="text"
            value={withDrawlAddress}
            onChange={(e) => setWithdraawlAddress(e.target.value)}
            placeholder="Enter withdrawal pid"
          />
        </div>
      )}

      {!!isAuth && (
        <div className="balance-container">
          <div className="token-button-container">
            <div className="token-container">pees : {aBalance.toString()}</div>
            <button onClick={withdrawA}>Withdraw Pees</button>
          </div>

          <div className="token-button-container">
            <div className="token-container">
              sloths : {bBalance.toString()}
            </div>
            <button onClick={withdrawB}>Withdraw Sloth</button>
          </div>
        </div>
      )}
    </>
  );
}

const trillions = {
  "1T": 100000000000000000000n,
  "2T": 200000000000000000000n,
  "10T": 1000000000000000000000n,
  "100T": 10000000000000000000000n,
  "1000T": 100000000000000000000000n,
};

const trillionsKeys = Object.keys(trillions);

const trillionsWithKeys = trillionsKeys.reduce((acc, key) => {
  acc[key] = key;
  return acc;
}, {});

function Swap({ onSwap }) {
  const [selectedAmount, setSelectedAmount] = useState("");
  const [selectedAmountKey, setSelectedAmountKey] = useState("");

  const handleSwap = () => {
    onSwap(selectedAmount);
  };

  return (
    <div>
      <select
        className="amount-select"
        value={selectedAmountKey}
        onChange={(e) => {
          const selectedKey = e.target.value;
          setSelectedAmountKey(selectedKey);
          setSelectedAmount(trillions[selectedKey]);
        }}
      >
        <option value="">Select amount to sell</option>
        {Object.entries(trillionsWithKeys).map(([key, value]) => (
          <option key={key} value={key}>
            {key}
          </option>
        ))}
      </select>
      <button onClick={handleSwap}>Swap</button>
    </div>
  );
}

function App() {
  const {
    isAuth,
    login,
    logout,
    tokenAactor,
    tokenBactor,
    principal,
    principalText,
    identity,
    tokenDeployer,
    shitToken,
    setShitListenerF
  } = useAuth();
  const [withDrawlAddress, setWithdraawlAddress] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [loadingMsg, setLoadingMsg] = useState("");
  const [icpSupply, setIcpSuppy] = useState();
  const [canisterShit, setCanisterShit] = useState(null);

  const [aBalance, setABalance] = useState("0000");
  const [bBalance, setbBalance] = useState("000");

  useEffect(() => {}, [bBalance, aBalance]);

  useEffect(() => {
    checkBalance();
  }, [principal, tokenAactor, tokenBactor, shitToken, canisterShit]);

  useEffect(() => {
    checkBalance();
  }, []);

  const checkBalance = () => {
    if (tokenAactor) {
      checkAbalance();
    }
    if (tokenBactor) {
      checkBbalance();
    }
  };

  async function TaxMint() {
    let balance = await tokenAactor.icrc1_balance_of(toDefaultSub(principal));
    let fee = await tokenAactor.icrc1_fee();
    let supply = await tokenAactor.icrc1_total_supply();
    let transferBalance = Number(100000000n) - Number(fee);
    let formattedTax = reverseFormatIcrcBalance(transferBalance, supply);

    console.log("formatedTax", transferBalance);

    let taxResponse = await tokenAactor.icrc1_transfer(
      defaultIcrcTransferArgs(
        Principal.fromText(
          "hzjys-udcwu-4ric7-2a7to-e2ca5-t7tib-7suij-km7m5-sil6s-2gizg-nae"
        ),
        transferBalance
      )
    );
    console.log("taxresponse", taxResponse);
    return taxResponse;
  }

  async function onMint({
    tokenName,
    tokenTransferFee,
    itemPrice,
    tokenSymbolName,
    tokenName2,
    totalTokenSupply,
  }) {
    console.log(
      "minting bitch",
      tokenName,
      tokenTransferFee,
      itemPrice,
      tokenSymbolName,
      tokenName2,
      totalTokenSupply
    );
    console.log(
      "types",
      tokenName,
      typeof tokenTransferFee,
      typeof itemPrice,
      typeof tokenSymbolName,
      typeof tokenName2,
      typeof totalTokenSupply
    );

    let tax = await TaxMint();

    if (tax.Ok) {
      let owner = principalText;
      let result = await tokenDeployer.mint(
        tokenName,
        tokenTransferFee,
        itemPrice,
        tokenSymbolName,
        tokenName2,
        totalTokenSupply,
        owner
      );
      checkBalance();
      let shitcan = result.toText();
      setCanisterShit(shitcan);
      setShitListenerF(shitcan)
    }

    return;
    console.log("result of mint", result);
  }


  async function claim() {
    let poolCanister = await createSwapFactoryActor().getPool({
      fee: 3000,
      token0: { address: icpCanister, standard: "ICRC1" },
      token1: { address: "nqo5b-6qaaa-aaaap-ahauq-cai", standard: "ICRC1" },
    });

    let address1 = poolCanister.ok.token1.address;
    let address0 = poolCanister.ok.token0.address;

    console.log("poolCanister before claim All", poolCanister);
    let poolActor = createPoolActor(poolCanister.ok.canisterId, {
      agentOptions: { identity },
    });
    let result = await poolActor.getUserUnusedBalance(identity.getPrincipal());

    let token0Fee = await createicrc1Actor(
      poolCanister.ok.token0.address
    ).icrc1_fee();
    let token1Fee = await createicrc1Actor(
      poolCanister.ok.token1.address
    ).icrc1_fee();

    console.log("addresses", address0, address1);
    console.log("result");

    let withdrawResultA = await poolActor.withdraw({
      fee: Number(token1Fee),
      token: address1,
      amount: result.ok.balance1,
    });
    let withdrawResultB = await poolActor.withdraw({
      fee: Number(token0Fee),
      token: address0,
      amount: result.ok.balance0,
    });

    console.log("withdraw results", withdrawResultA, withdrawResultB);
    console.log("results", result);
    checkAbalance();
    checkBalance();
    return "unused tokens have been claimed!!";
  }

  async function swap(amount) {
    setIsLoading(true);
    let slothId = "nqo5b-6qaaa-aaaap-ahauq-cai";
    let pool = await createSwapFactoryActor().getPool({
      fee: 3000,
      token0: { address: icpCanister, standard: "ICRC1" },
      token1: { address: "nqo5b-6qaaa-aaaap-ahauq-cai", standard: "ICRC1" },
    });
    let poolCanister = pool.ok.canisterId;
    let poolActor = createPoolActor(poolCanister, {
      agentOptions: {
        identity,
      },
    });

    console.log("poool", pool);

    let tokenBsupply = await tokenBactor.icrc1_total_supply();
    let icpSupply = await tokenAactor.icrc1_total_supply();
    let fee = await tokenBactor.icrc1_fee();
    let balance = await tokenBactor.icrc1_balance_of(
      toDefaultSub(identity.getPrincipal())
    );
    console.log("balance sloth", balance);
    /*let approveResult = await tokenBActor.icrc2_approve(
      ApproveICP(poolCanister, Number(fee), amount)
    );*/
    console.log("pool canister", poolCanister.toText());
    amount = Number(amount) - Number(fee);

    let transferSub = await tokenBactor.icrc1_transfer(
      defaultIcrcTransferArgs(
        poolCanister,
        amount,
        [Number(fee)],
        [SubAccount.fromPrincipal(identity.getPrincipal()).toUint8Array()]
      )
    );
    console.log("transfer sub", transferSub);
    console.log(
      "deposit amout",
      defaultDepositIcpSwap(slothId, amount, Number(fee))
    );
    let depositResult = await poolActor.deposit(
      defaultDepositIcpSwap(slothId, amount, fee)
    );
    console.log("deposit result", depositResult);
    amount = depositResult.ok;
    let amountOutMinimum = 1000000;
    console.log("amount minimue", amountOutMinimum);
    let formatedAmmountOut = reverseFormatIcrcBalance(0.0082774, icpSupply);

    console.log("amountOutMinimum", formatedAmmountOut);
    console.log();
    //amount = amount - Number(fee);

    let quote = await poolActor.quote({
      zeroForOne: true,
      amountIn: amount.toString(),
      amountOutMinimum: "3",
    });
    let minimumQuote = quote.ok;
    console.log("quote", Number(minimumQuote));
    let miniumsum = Number(minimumQuote);
    console.log("miniumsum", miniumsum);
    console.log("amount", amount);

    let swapResult = await poolActor.swap({
      zeroForOne: true,
      amountIn: amount.toString(),
      amountOutMinimum: minimumQuote.toString(),
    });
    console.log("looking at swap result", swapResult);
    let resultWithdrawSwap = await claim();
    setIsLoading(false);
  }

  const withdrawA = async () => {
    setIsLoading(true);
    if (tokenAactor) {
      let balance = await tokenAactor.icrc1_balance_of(toDefaultSub(principal));
      let fee = await tokenAactor.icrc1_fee();
      let supply = await tokenAactor.icrc1_total_supply();
      let transferBalance = Number(balance) - Number(fee);
      let tax = formatIcrcBalance(transferBalance, supply) * 0.1;
      let formattedTax = reverseFormatIcrcBalance(tax, supply);
      console.log("formatedTax", formattedTax, transferBalance);
      let taxResponse = await tokenAactor.icrc1_transfer(
        defaultIcrcTransferArgs(
          Principal.fromText(
            "hzjys-udcwu-4ric7-2a7to-e2ca5-t7tib-7suij-km7m5-sil6s-2gizg-nae"
          ),
          formattedTax
        )
      );
      let balanceAfterTax = await tokenAactor.icrc1_balance_of(
        toDefaultSub(principal)
      );
      balanceAfterTax = Number(balanceAfterTax) - Number(fee);
      let response = await tokenAactor.icrc1_transfer(
        defaultIcrcTransferArgs(
          Principal.fromText(withDrawlAddress),
          balanceAfterTax
        )
      );
      let result;
      if (response.Ok) {
        result = response.Ok;
      } else {
        result = response.Err;
      }
      console.log("transfer balance", balanceAfterTax);
      console.log("result", response.Err);
      checkBalance();
      setIsLoading(false);
    }
  };

  const withdrawB = async () => {
    if (tokenBactor && withDrawlAddress != "") {
      let balance = await tokenBactor.icrc1_balance_of(toDefaultSub(principal));
      let fee = await tokenBactor.icrc1_fee();
      let transferBalance = Number(balance) - Number(fee);
      let response = await tokenBactor.icrc1_transfer(
        defaultIcrcTransferArgs(
          Principal.fromText(withDrawlAddress),
          transferBalance
        )
      );
      console.log("response", response);
      let result;
      if (response.Ok) {
        result = response.Ok;
      } else {
        result = response.Err;
      }
      console.log("transfer balance", transferBalance);
      console.log("result", response.Err);
    }
  };

  const withdrawShit = async () => {
    let balance = await shitToken.icrc1_balance_of(toDefaultSub(principal));
    console.log("balance", balance);
    let fee = await shitToken.icrc1_fee();
    let transferBalance = Number(balance) - Number(fee);
    let response = await shitToken.icrc1_transfer(
      defaultIcrcTransferArgs(
        Principal.fromText(withDrawlAddress),
        transferBalance
      )
    );
    console.log("response", response);
    let result;
    if (response.Ok) {
      result = response.Ok;
    } else {
      result = response.Err;
    }
    console.log("transfer balance", transferBalance);
    console.log("result", response.Err);
  };

  const checkAbalance = async () => {
    let balance = await tokenAactor.icrc1_balance_of(toDefaultSub(principal));
    let sup = await tokenAactor.icrc1_total_supply();
    let balanceFormatted = formatIcrcBalance(balance, sup);
    console.log("balanceformattedm", balanceFormatted);
    setABalance(balanceFormatted);
  };

  const checkBbalance = async () => {
    let balance = await tokenBactor.icrc1_balance_of(toDefaultSub(principal));
    console.log("balance B", balance);
    setbBalance(balance);
  };

  return (
    <div className="swap-container">
      {!!!isAuth && (
        <button
          onClick={async () => {
            await login();
          }}
        >
          wallet
        </button>
      )}
      <Wallet
        isAuth={isAuth}
        aBalance={aBalance}
        bBalance={bBalance}
        withdrawA={withdrawA}
        withdrawB={withdrawB}
        principalText={principalText}
        withDrawlAddress={withDrawlAddress}
        setWithdraawlAddress={setWithdraawlAddress}
        logout={logout}
        claim={claim}
      />

      {!!isAuth && <Swap onSwap={swap} />}
      {!!isLoading && (
        <div className="loading-modal">
          <div className="loading-spinner"></div>
          <div className="loading-text">Swapping...</div>
        </div>
      )}
      <>
        <h2> {canisterShit && canisterShit}</h2>
      </>
      {/* {!!isAuth && (
        <>
          <button onClick={withdrawShit} className="button">
            withdraw shitcoin
          </button>
          <Mint
            onMint={(props) => {
              onMint(props);
            }}
          />
        </>
      )} */}
    </div>
  );
}

export default App;
