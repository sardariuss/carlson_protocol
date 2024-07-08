import                        './styles.scss';
import App               from './components/App';

import { HashRouter }    from "react-router-dom";
import ReactDOM          from 'react-dom/client';
import { AgentProvider, ActorProvider } from "@ic-reactor/react";
import { idlFactory, canisterId } from '../declarations/backend';
import React from 'react';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <AgentProvider withProcessEnv>
      <ActorProvider idlFactory={idlFactory} canisterId={canisterId}>
        <HashRouter>
          <App/>
        </HashRouter>
      </ActorProvider>
    </AgentProvider>
  </React.StrictMode>
);
