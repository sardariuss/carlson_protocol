import Grunts from "./Grunts";
import Header from "./Header";
import Footer from "./Footer";

import { Route, Routes }   from "react-router-dom";
//import { ActorProvider, useAuth } from "@ic-reactor/react";
//import { useActorStore, useAuth, useQueryCall } from "./actors"
import { useQueryCall, useUpdateCall, useAuth } from '@ic-reactor/react';

function App () {

  const {login, logout, authenticated, identity} = useAuth()

  const { call: fetchGrunts, data: grunts } = useQueryCall({
    functionName: 'get_grunts',
    onSuccess: (data) => {
      console.log(data)
    }
  });

  const { call: addGrunt, loading } = useUpdateCall({
    functionName: 'add_grunt',
    args: ["First grunt!"],
    onSuccess: (data) => {
      console.log(data)
      fetchGrunts();
    },
  });

  return (
    <div className="flex flex-col min-h-screen w-full bg-white dark:bg-slate-900 dark:border-gray-700 justify-between">
      <div className="flex flex-col w-full flex-grow">
        <Header/>
        <div>
          <div>{identity?.getPrincipal().toText()}</div>
          <button onClick={() => { if(authenticated){ logout() } else { login() } }}>
            { authenticated ? "logout" : "login" }
          </button>
        </div>
        <div>
          <button onClick={addGrunt} disabled={loading}>
            Add a new grunt
          </button>
          <ul>
            {
              grunts && grunts.length > 0 ? (
                grunts.map((grunt, index) => (
                  <li key={index}>{grunt}</li>
                ))
              ) : (
                <li>No grunts available</li>
              )
            }
          </ul>
        </div>
      </div>
      <Footer/>
    </div>
  )
}

export default App;