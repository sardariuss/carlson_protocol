import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
import { AuthProvider } from "./auth.jsx";
import "./index.css";
import { Buffer } from "buffer/";
import { SwapProvider } from "./hooks/swap.jsx";
globalThis.Buffer = Buffer;

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <AuthProvider>
      <SwapProvider>
        <App />
      </SwapProvider>
    </AuthProvider>
  </React.StrictMode>
);
