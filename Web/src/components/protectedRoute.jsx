// src/components/ProtectedRoute.jsx
import { Navigate } from "react-router-dom";

function ProtectedRoute({ children }) {
  const access_token = localStorage.getItem("access_token");
  return access_token ? children : <Navigate to="/" replace />;
}
export default ProtectedRoute;
