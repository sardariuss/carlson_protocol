import { Route, Routes } from "react-router-dom";
import { useAuth } from "@ic-reactor/react";

import PrivateRoute from "./PrivateRoute";
import GruntList from "../components/GruntList";
import User from "../components/user/User";

const Router = () => {
    const { identity } = useAuth({});
  
    return (
      <Routes>
        <Route path={"/"} element={<GruntList />} />
        <Route path={"/user/:principal"} element={<User />} />
      </Routes>
    );
  };
  
  export default Router;
  