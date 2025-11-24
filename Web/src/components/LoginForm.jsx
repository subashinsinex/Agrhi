import React, { useState } from "react";
import { login } from "../api/login";
import { useNavigate } from "react-router-dom";

const formStyles = `
.login-form-wrapper {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f8f8;
  font-family: 'Segoe UI', Verdana, Geneva, Tahoma, sans-serif;
}
.login-form {
  background: #fff;
  padding: 2rem;
  border-radius: 10px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.10);
  width: 320px;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
.login-form h2 {
  margin: 0 0 1rem 0;
  text-align: center;
  color: #1667d5;
}
.login-form input[type="text"], 
.login-form input[type="password"] {
  padding: 0.8rem;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 1rem;
  outline: none;
  transition: border-color 0.2s;
}
.login-form input:focus {
  border-color: #1667d5;
}
.login-form button {
  padding: 0.8rem;
  background: #1667d5;
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s;
}
.login-form button:hover {
  background: #104e9e;
}
.login-message {
  text-align: center;
  color: #e74c3c;
  font-size: 1rem;
  margin-top: 1rem;
}
@media (max-width: 400px) {
  .login-form {
    width: 95%;
    padding: 1rem;
  }
}

.password-input-wrapper {
  position: relative;
  width: 100%;
  display: flex;
  align-items: center;
}
.password-input-wrapper input[type="password"],
.password-input-wrapper input[type="text"] {
  width: 100%;
  padding-right: 2.5rem;
  box-sizing: border-box;
}
.password-input-wrapper button.eye-icon-btn {
  position: absolute;
  right: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
  margin: 0;
  display: flex;
  align-items: center;
  height: 100%;
}

`;

const LoginForm = () => {
  const [phone_number, setUserId] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    const platform = "web";
    const result = await login(phone_number, password, platform);
    if (result.success) {
      localStorage.setItem("access_token", result.access_token);
      localStorage.setItem("refresh_token", result.refresh_token);
      setMessage("Login successful. Redirecting...");
      setTimeout(() => {
        navigate("/dashboard");
      }, 1000);
    } else {
      setMessage(result.message);
    }
  };

  return (
    <div className="login-form-wrapper">
      {/* Inline CSS injection */}
      <style>{formStyles}</style>
      <form className="login-form" onSubmit={handleSubmit}>
        <h2>Admin Login</h2>
        <input
          type="text"
          placeholder="Phone Number"
          value={phone_number}
          onChange={(e) => setUserId(e.target.value)}
          required
        />
        <div className="password-input-wrapper">
          <input
            type={showPassword ? "text" : "password"}
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button
            type="button"
            className="eye-icon-btn"
            onClick={() => setShowPassword((prev) => !prev)}
            tabIndex={-1}
            aria-label={showPassword ? "Hide password" : "Show password"}
          >
            {/* Eye Icon SVG */}
            {showPassword ? (
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="22"
                height="22"
                fill="none"
                viewBox="0 0 24 24"
                style={{ display: "block", fill: "#888" }}
              >
                <path d="M12 5c-7.633 0-12 7.219-12 7.219s4.367 7.219 12 7.219 12-7.219 12-7.219-4.367-7.219-12-7.219zm0 12.844c-3.365 0-6.095-2.124-7.759-4.312 1.651-2.196 4.382-4.313 7.759-4.313 3.365 0 6.096 2.117 7.758 4.313-1.652 2.188-4.393 4.312-7.758 4.312zm0-7.047c-1.513 0-2.741 1.227-2.741 2.735s1.228 2.734 2.741 2.734 2.742-1.226 2.742-2.734-1.229-2.735-2.742-2.735zm0 4.344c-.893 0-1.613-.721-1.613-1.609s.72-1.609 1.613-1.609 1.614.721 1.614 1.609-.721 1.609-1.614 1.609z" />
              </svg>
            ) : (
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="22"
                height="22"
                fill="none"
                viewBox="0 0 24 24"
                style={{ display: "block", fill: "#888" }}
              >
                <path d="M1 12S5.367 5 12 5s11 7 11 7-4.367 7-11 7S1 12 1 12zm11 3a3 3 0 100-6 3 3 0 000 6z" />
              </svg>
            )}
          </button>
        </div>

        <button type="submit">Login</button>
        {message && <div className="login-message">{message}</div>}
      </form>
    </div>
  );
};

export default LoginForm;
