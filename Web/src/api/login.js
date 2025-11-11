import axios from "axios";
import { SERVER_IP, SERVER_PORT } from "../constant";

// Create Axios instance for all authenticated requests
const axiosInstance = axios.create({
  baseURL: `http://${SERVER_IP}:${SERVER_PORT}`,
});

// Interceptor for refreshing token if access token expired
axiosInstance.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (
      error.response &&
      error.response.status === 401 &&
      !originalRequest._retry
    ) {
      originalRequest._retry = true;
      const refresh_token = localStorage.getItem("refresh_token");

      if (refresh_token) {
        try {
          const result = await refreshAccessToken(refresh_token);

          // Only succeed if backend really issues a new access token
          if (result.success && result.access_token) {
            localStorage.setItem("access_token", result.access_token);
            originalRequest.headers[
              "Authorization"
            ] = `Bearer ${result.access_token}`;
            return axiosInstance(originalRequest); // retry original
          } else {
            // Backend or token issue: logout
            localStorage.removeItem("access_token");
            localStorage.removeItem("refresh_token");
            window.location.href = "/login";
            return Promise.reject(error);
          }
        } catch (e) {
          // Possible network/server error: log and don't logout unless absolutely needed
          console.error("Token refresh network/server error", e);

          // Optionally: show an error to user, or retry a limited number of times
          localStorage.removeItem("access_token");
          localStorage.removeItem("refresh_token");
          window.location.href = "/login";
          return Promise.reject(error);
        }
      } else {
        // No refresh token present
        localStorage.removeItem("access_token");
        window.location.href = "/login";
        return Promise.reject(error);
      }
    }
    // Other errors, propagate
    return Promise.reject(error);
  }
);

// Login API function
export async function login(phone_number, password, platform) {
  try {
    const response = await axios.post(
      `http://${SERVER_IP}:${SERVER_PORT}/api/login`,
      {
        phone_number,
        password,
        platform,
      }
    );
    return {
      success: true,
      access_token: response.data.access_token,
      refresh_token: response.data.refresh_token,
      message: response.data.message,
    };
  } catch (error) {
    if (error.response) {
      // Backend error response
      return { success: false, message: error.response.data.message };
    } else {
      // Network/server error
      return { success: false, message: "Login failed, server error." };
    }
  }
}

// Refresh token API function
export async function refreshAccessToken(refresh_token) {
  try {
    const response = await axios.post(
      `http://${SERVER_IP}:${SERVER_PORT}/api/refreshtoken`,
      { refresh_token }
    );
    return {
      success: true,
      access_token: response.data.access_token,
      message: response.data.message,
    };
  } catch (error) {
    return { success: false, message: "Refresh failed" };
  }
}

export { axiosInstance };

// Example usage for protected requests:
// const token = localStorage.getItem("access_token");
// const response = await axiosInstance.get("/api/your_protected_route", {
//   headers: { Authorization: `Bearer ${token}` }
// });
