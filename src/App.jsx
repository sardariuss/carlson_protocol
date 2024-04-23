import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom";
import { useAuth } from "./auth";

const App = () => {
  const [isAuth,principalText] = useAuth();

  useEffect(() => {}, [isAuth]);

  return ( 
<div>
  {isAuth && <div>principalID: {principalText}</div>}
  {!isAuth && <div> not logged in</div>}
</div>
  );
};

export default App;