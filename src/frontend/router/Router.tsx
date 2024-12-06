import { Route, Routes } from "react-router-dom";
import { useAuth } from "@ic-reactor/react";

import PrivateRoute from "./PrivateRoute";
import VoteList from "../components/VoteList";
import User from "../components/user/User";
import Info from "../components/Info";

const Router = () => {
    const { identity } = useAuth({});
  
    return (
      <Routes>
        <Route path={"/"} element={<VoteList />} />
        <Route path={"/info"} element={<Info />} />
        <Route path={"/user/:principal"} element={<User />} />
      </Routes>
    );
  };
  
  export default Router;
  