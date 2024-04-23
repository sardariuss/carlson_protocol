import { AuthClient } from "@dfinity/auth-client";
import React, { createContext, useContext, useEffect, useState } from "react";

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




  async function updateClient(client) {
    const isAuthenticated = await client.isAuthenticated();
    setIsAuthenticated(isAuthenticated);
    const identity = client.getIdentity();
    setIdentity(identity);
    const principal = identity.getPrincipal();
    let principalText = Principal.fromUint8Array(principal._arr).toText();

    let Aactor = createActor(canisterId, {
      agentOptions: {
        identity,
      },
    });


   



    setPrincipalText(principalText);
    setPrincipal(principal);
    setTokenAactorState(Aactor);
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
