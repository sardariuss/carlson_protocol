import                        './styles.css';
import                        './styles.scss';
import App               from './components/App';

import { HashRouter }    from "react-router-dom";
import ReactDOM          from 'react-dom/client';
import { AgentProvider } from "@ic-reactor/react";
import { BackendActorProvider } from "./actors/BackendActor"
import { CkBtcActorProvider } from './actors/CkBtcActor';
import { ProtocolActorProvider } from './actors/ProtocolActor';
import React from 'react';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <AgentProvider withProcessEnv>
      <HashRouter>
       <BackendActorProvider>
        <CkBtcActorProvider>
          <ProtocolActorProvider>
            <App/>
          </ProtocolActorProvider>
        </CkBtcActorProvider>
       </BackendActorProvider>
      </HashRouter>
    </AgentProvider>
  </React.StrictMode>
);
