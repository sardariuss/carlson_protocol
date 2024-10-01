import { useAuth } from "@ic-reactor/react";
import { Navigate } from "react-router-dom";
import React from "react";

type PrivateRouteProps = {
  element: React.ReactNode;
};

function PrivateRoute({ element }: PrivateRouteProps) {
  const { authenticated } = useAuth({});

  if (!authenticated) {
    return <Navigate to="/login" />;
  }

  return <>{element}</>;
}

export default PrivateRoute;
