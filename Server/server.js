require("dotenv").config({ quiet: true });
const express = require("express");
const cors = require("cors");

// Routes
const userAuthRoutes = require("./routes/user_auth");

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

// Route Api Mappings
app.use("/api/auth", userAuthRoutes);

// Server setup
const PORT = process.env.Server_Port;
const HOST = process.env.Server_Address;

// Start the server
app.listen(PORT, HOST, () => {
  console.log(`Server is running on ${HOST}:${PORT}`);
});
