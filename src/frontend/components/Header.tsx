import { Link, useNavigate }      from "react-router-dom";
import { useEffect } from "react";
import { useAuth } from "@ic-reactor/react";
import Balance from "./Balance";


const Header = () => {

  const navigate = useNavigate();

  const { login, logout, authenticated, identity } = useAuth({});

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
    <header className="bg-slate-100 dark:bg-gray-800 sticky top-0 z-30 flex flex-row items-center w-full justify-between space-x-2 xl:px-4 lg:px-3 md:px-2 px-2 xl:h-18 lg:h-16 md:h-14 h-14">
      <Link to="/" className="flex flex-row items-center space-x-1">
        <div className="flex flex-row space-x-1 items-center">
          <span className="xl:text-4xl text-xl font-wild-wolf whitespace-nowrap dark:text-grunt-green text-grunt-pink drop-shadow-lg shadow-white"> GRUNT </span>
          <span className="xl:text-3xl text-lg font-neon-spark whitespace-nowrap drop-shadow shadow-blue-800 tracking-widest neon-effect ">.defi </span>
        </div>
      </Link>
      <div className="flex flex-row items-center justify-center md:space-x-4">
      </div>
      <div className="flex flex-row items-center justify-end md:space-x-4 space-x-2">
        { authenticated && identity ? 
          <div className="flex flex-row items-center justify-end">
            <Balance/>
            <button type="button" onClick={() => { navigate("/user/" + identity.getPrincipal()) }} className="button-blue xl:text-lg lg:text-md md:text-sm text-sm">
              Profile
            </button>
          </div> :
          <button type="button" onClick={() => { login() }} className="button-blue xl:text-lg lg:text-md md:text-sm text-sm">
            Log in
          </button>
        }
        <button id="theme-toggle" type="button" className="fill-indigo-600 hover:fill-indigo-900 dark:fill-yellow-400 dark:hover:fill-yellow-200 rounded-lg text-sm p-2.5">
          <svg id="theme-toggle-dark-icon" className="hidden w-5 h-5" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path></svg>
          <svg id="theme-toggle-light-icon" className="hidden w-5 h-5" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" fillRule="evenodd" clipRule="evenodd"></path></svg>
        </button>
      </div>
    </header>
  );
}

export default Header;