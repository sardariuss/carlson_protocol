import { Link, useNavigate }      from "react-router-dom";
import { useEffect } from "react";
import { useAuth } from "@ic-reactor/react";

import "@nfid/identitykit/react/styles.css"

import { IdentityKitProvider, IdentityKitTheme, ConnectWalletButton } from "@nfid/identitykit/react"
import { NFIDW, IdentityKitAuthType } from "@nfid/identitykit"


const Header = () => {

  //const navigate = useNavigate();
//
  //const { login, logout, authenticated, identity } = useAuth({});

  useEffect(() => {

    var themeToggleDarkIcon = document.getElementById('theme-toggle-dark-icon');
    var themeToggleLightIcon = document.getElementById('theme-toggle-light-icon');
    var themeToggleBtn = document.getElementById('theme-toggle');

    if (themeToggleDarkIcon == null || themeToggleLightIcon == null || themeToggleBtn == null) {
      return;
    };
  
    // Change the icons inside the button based on previous settings
    if (localStorage.getItem('color-theme') === 'dark' || (!('color-theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      themeToggleLightIcon.classList.remove('hidden');
    } else {
      themeToggleDarkIcon.classList.remove('hidden');
    }
  
    themeToggleBtn.addEventListener('click', function() {
  
      // toggle icons inside button
      if (themeToggleDarkIcon !== null) {
        themeToggleDarkIcon.classList.toggle('hidden');
      }
      if (themeToggleLightIcon !== null) {
        themeToggleLightIcon.classList.toggle('hidden');
      }

      // if set via local storage previously
      if (localStorage.getItem('color-theme')) {
        if (localStorage.getItem('color-theme') === 'light') {
          document.documentElement.classList.add('dark');
          localStorage.setItem('color-theme', 'dark');
        } else {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('color-theme', 'light');
        }

      // if NOT set via local storage previously
      } else {
        if (document.documentElement.classList.contains('dark')) {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('color-theme', 'light');
        } else {
          document.documentElement.classList.add('dark');
          localStorage.setItem('color-theme', 'dark');
        }
      }
    });

  }, []);

  return (
    <IdentityKitProvider 
      onConnectFailure={(e: Error) => {console.error(e)}}
      onConnectSuccess={() => {console.log("Connected")}}
      onDisconnect={() => {console.log("Disconnected")}}
      signers={[NFIDW]}
      theme={IdentityKitTheme.LIGHT} // LIGHT, DARK, SYSTEM (by default)
      authType={IdentityKitAuthType.ACCOUNTS} // ACCOUNTS, DELEGATION (by default)
    >
      <ConnectWalletButton />
    </IdentityKitProvider>
  );
}

export default Header;