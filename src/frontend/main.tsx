import                                  './styles.css';
import                                  './styles.scss';
import App                              from './components/App';

import ReactDOM                         from 'react-dom/client';
import { StrictMode }                   from 'react';
import { AgentProvider }                from "@ic-reactor/react";
import { BackendActorProvider }         from "./actors/BackendActor"
import { CkBtcActorProvider }           from './actors/CkBtcActor';
import { ProtocolActorProvider }        from './actors/ProtocolActor';
import { PresenceLedgerActorProvider }  from './actors/PresenceLedgerActor';
import { ResonanceLedgerActorProvider } from './actors/ResonanceLedgerActor';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <AgentProvider withProcessEnv>
      <BackendActorProvider>
        <CkBtcActorProvider>
          <PresenceLedgerActorProvider>
            <ResonanceLedgerActorProvider>
              <ProtocolActorProvider>
                <App/>
              </ProtocolActorProvider>
            </ResonanceLedgerActorProvider>
          </PresenceLedgerActorProvider>
        </CkBtcActorProvider>
      </BackendActorProvider>
    </AgentProvider>
  </StrictMode>
);
