import Header from "./Header";
import Footer from "./Footer";

import { SYesNoVote } from "@/declarations/backend/backend.did";
import { backendActor } from "./actors"
import { useAuth } from "@ic-reactor/react";

function App () {

  const { login, logout, authenticated, identity } = useAuth()

  const { call: fetchGrunts, data: grunts } = backendActor.useQueryCall({
    functionName: 'get_grunts',
    onSuccess: (data) => {
      console.log(data)
    }
  });

  const { call: addGrunt, loading } = backendActor.useUpdateCall({
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
              Array.isArray(grunts) ? (
                grunts.map((grunt: SYesNoVote, index) => (
                  <li key={index}>{grunt.text}</li>
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