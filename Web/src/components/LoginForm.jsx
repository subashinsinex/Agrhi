import React, { useState } from 'react';
import { login } from '../api/login';
import { useNavigate } from 'react-router-dom';

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
`;

const LoginForm = () => {
  const [phone_number, setUserId] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    const platform = 'web';
    const result = await login(phone_number, password, platform);
    if (result.success) {
      localStorage.setItem('token', result.token);
      setMessage('Login successful. Redirecting...');
      setTimeout(() => {
        navigate('/dashboard');
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
          onChange={e => setUserId(e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={e => setPassword(e.target.value)}
          required
        />
        <button type="submit">Login</button>
        {message && <div className="login-message">{message}</div>}
      </form>
    </div>
  );
};

export default LoginForm;
