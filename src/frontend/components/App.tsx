import Header from "./Header";
import Footer from "./Footer";
import { createContext, useState, useEffect } from "react";
import { BrowserRouter, useLocation } from "react-router-dom";

import Router from "../router/Router";

const originalConsoleError = console.error;

console.error = (...args) => {
  // Ignore nivo warnings: https://github.com/plouc/nivo/issues/2612
  if (typeof args[2] === 'string' && args[2].includes('The prop `legendOffsetX` is marked as required')) {
    return;
  }
  if (typeof args[2] === 'string' && args[2].includes('The prop `legendOffsetY` is marked as required')) {
    return;
  }
  originalConsoleError(...args);
};

interface ThemeContextProps {
  theme: string;
  setTheme: (theme: string) => void;
}

export const ThemeContext = createContext<ThemeContextProps>({
  theme: "light",
  setTheme: (theme) => console.warn("no theme provider"),
});

function App() {
  const [theme, setTheme] = useState("dark");

  const rawSetTheme = (rawTheme: string) => {
    const root = window.document.documentElement;
    const isDark = rawTheme === "dark";

    root.classList.remove(isDark ? "light" : "dark");
    root.classList.add(rawTheme);
    setTheme(rawTheme);
  };

  if (typeof window !== "undefined") {
    useEffect(() => {
      const initialTheme = window.localStorage.getItem("color-theme");
      window.matchMedia("(prefers-color-scheme: dark)").matches && !initialTheme
        ? rawSetTheme("dark")
        : rawSetTheme(initialTheme || "light");
    }, []);

    useEffect(() => {
      window.localStorage.setItem("color-theme", theme);
    }, [theme]);
  }

  return (
    <ThemeContext.Provider value={{ theme, setTheme: rawSetTheme }}>
      <div className="flex h-screen w-full flex-col sm:flex-row">
        <BrowserRouter>
          <AppContent />
        </BrowserRouter>
      </div>
    </ThemeContext.Provider>
  );
}

function AppContent() {

  return (
    <>
      <div className="flex flex-col min-h-screen w-full bg-white dark:bg-slate-900 dark:border-gray-700 border-gray-200 dark:text-white text-black justify-between">
        <div className="flex flex-col w-full flex-grow items-center">
          <Header/>
          <Router/>
        </div>
        <Footer/>
      </div>
    </>
  );
}

export default App;