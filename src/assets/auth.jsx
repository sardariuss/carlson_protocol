import { AuthClient } from "@dfinity/auth-client";
import React, { createContext, useContext, useEffect, useState } from "react";
import { createicrc1Actor } from "./ic/icpswap/icrc1/index.js";
import { createTokenlistActor } from "./ic/icpswap/tokenList/index.js";
import { createPoolActor } from "./ic/icpswap/pool/index.js";
import { createSwapFactoryActor } from "./ic/icpswap/swapV3/index.js";
import { Principal } from "@dfinity/principal";
import {
  createActor,
  canisterId,
} from "../src/declarations/fungibletoken_backend";

const AuthContext = createContext(null);

console.log("process", process.env);

const defaultOptions = {
  /**
   *  @type {import("@dfinity/auth-client").AuthClientCreateOptions}
   */
  createOptions: {
    idleOptions: {
      // Set to true if you do not want idle functionality
    },
  },
  /**
   * @type {import("@dfinity/auth-client").AuthClientLoginOptions}
   */
  loginOptions: {
    identityProvider:
      process.env.DFX_NETWORK === "ic"
        ? "https://identity.ic0.app/#authorize"
        : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:8000/#authorize`,
  },
};

/**
 *
 * @param options - Options for the AuthClient
 * @param {AuthClientCreateOptions} options.createOptions - Options for the AuthClient.create() method
 * @param {AuthClientLoginOptions} options.loginOptions - Options for the AuthClient.login() method
 * @returns
 */
export const useAuthClient = (options = defaultOptions) => {
  const [isAuth, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState(null);
  const [identity, setIdentity] = useState(null);
  const [principal, setPrincipal] = useState(null);
  const [principalText, setPrincipalText] = useState(null);
  const [tokenAactor, setTokenAactorState] = useState(null);
  const [tokenBactor, setTokenBactorState] = useState(null);
  const [poolActor, setPoolActorState] = useState(null);
  const [swapfactory, setSwapFactoryState] = useState(null);
  const [tokenDeployer, setTokenDeployer] = useState(null);
  const [shitToken, setShitToken] = useState(null);
  const [shitListener, setShitListener] = useState("nqo5b-6qaaa-aaaap-ahauq-cai");

  useEffect(() => {
    // Initialize AuthClient
    AuthClient.create(options.createOptions).then(async (client) => {
      console.log("coool",client)
      updateClient(client);
    });
  }, [shitListener]);

  const login = () => {
    authClient.login({
      ...options.loginOptions,
      onSuccess: () => {
        console.log("on sucess");
        updateClient(authClient);
      },
    });
  };

  const initSwapFactory = async () => {
    let factory = await createSwapFactoryActor();
    setSwapFactoryState(factory);
  };

  const setShitListenerF = (shit)=>{
      setShitListener(shit)
  }

  const setPoolActor = (pool) => {
    let poolid = pool.ok.canisterId;
    let Actor = createPoolActor(poolid);
    setPoolActorState(Actor);
  };

  const setTokenAactor = async (canisterId) => {
    let actor = createicrc1Actor(canisterId, {
      agentOption: {
        identity,
      },
    });
    setTokenAactorState(actor);
  };

  const setTokenBactor = (canisterId) => {
    let actor = createicrc1Actor(canisterId, {
      agentOption: {
        identity,
      },
    });
    setTokenBactorState(actor);
  };

  async function updateClient(client) {
    const isAuthenticated = await client.isAuthenticated();
    console.log("updating client", isAuthenticated);
    setIsAuthenticated(isAuthenticated);

    const identity = client.getIdentity();
    setIdentity(identity);

    const principal = identity.getPrincipal();
    console.log("principal", principal);
    let principalText = Principal.fromUint8Array(principal._arr).toText();
    console.log("principalText", principalText);

    let icpCanister = "ryjl3-tyaaa-aaaaa-aaaba-cai";
    console.log("creating actors")
    let shitTokenActor = createicrc1Actor(shitListener, {
      agentOptions: {
        identity,
      },
    });

    let Aactor = createicrc1Actor(icpCanister, {
      agentOptions: {
        identity,
      },
    });

    let Bactor = createicrc1Actor("nqo5b-6qaaa-aaaap-ahauq-cai", {
      agentOptions: {
        identity,
      },
    });

    let tokenDep = createActor(canisterId, {
      agentOptions: {
        identity,
      },
    });



   

    setShitToken(shitTokenActor);

    setPrincipalText(principalText);
    setPrincipal(principal);
    setTokenAactorState(Aactor);
    setTokenBactorState(Bactor);
    setTokenDeployer(tokenDep);
    setAuthClient(client);
  }

  async function logout() {
    await authClient?.logout();
    await updateClient(authClient);
  }

  return {
    isAuth,
    login,
    logout,
    setTokenAactor,
    setTokenBactor,
    setPoolActor,
    initSwapFactory,
    authClient,
    identity,
    principal,
    tokenAactor,
    tokenBactor,
    swapfactory,
    poolActor,
    principalText,
    tokenDeployer,
    shitToken,
    shitListener,
    setShitListenerF
  };
};

/**
 * @type {React.FC}
 */
export const AuthProvider = ({ children }) => {
  const auth = useAuthClient();
  return <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);
