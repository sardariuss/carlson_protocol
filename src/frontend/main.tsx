import ReactDOM                         from 'react-dom/client';
import { ConnectWalletButton, IdentityKitProvider, IdentityKitTheme } from '@nfid/identitykit/react';
import { IdentityKitAuthType, NFIDW, InternetIdentity } from '@nfid/identitykit';

import "@nfid/identitykit/react/styles.css"

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <IdentityKitProvider
    signers={[NFIDW, InternetIdentity]}
    theme={IdentityKitTheme.LIGHT}
    authType={IdentityKitAuthType.DELEGATION}
  >
    <ConnectWalletButton/>
  </IdentityKitProvider>
);