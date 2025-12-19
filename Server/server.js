require("dotenv").config();
const express = require("express");
const cors = require("cors");
const requestIp = require("request-ip");
const emailService = require("./utils/emailSender");

const app = express();

// CRITICAL: Enable trust proxy BEFORE other middleware
app.set("trust proxy", true);

// Middleware
app.use(cors());
app.use(express.json());
app.use(requestIp.mw()); // Extracts real client IP (works behind WiFi/proxy/NAT)

// Routes
const loginRoutes = require("./routes/loginRoutes");
const userRoutes = require("./routes/userManageRoutes");
const subsidiesRoutes = require("./routes/subsidiesRoutes");
const farmCropRoutes = require("./routes/farmCropRoutes");
const diseaseRemediesRoutes = require("./routes/diseaseRemediesRoutes");
const profileRoutes = require("./routes/profileRoutes");
const feedbackRoutes = require("./routes/feedbackRoutes");
const syncRoutes = require("./routes/syncRoutes");
const forgotPasswordRoutes = require("./routes/forgotPasswordRoutes");
const emailVerificationRoutes = require("./routes/emailVerificationRoutes");

app.use("/api", loginRoutes);
app.use("/api/users", userRoutes);
app.use("/api/subsidies", subsidiesRoutes);
app.use("/api/farmcrop", farmCropRoutes);
app.use("/api/diseaseRemedies", diseaseRemediesRoutes);
app.use("/api/profile", profileRoutes);
app.use("/uploads", express.static("uploads"));
app.use("/models", express.static("models"));
app.use("/api/feedback", feedbackRoutes);
app.use("/api/sync", syncRoutes);
app.use("/api/forgot-password", forgotPasswordRoutes);
app.use("/api/email-verification", emailVerificationRoutes);

const PORT = process.env.PORT;

app.listen(PORT, async () => {
  console.log(`\n🚀 Server is running on port ${PORT}`);
  console.log(`📍 Server URL: http://localhost:${PORT}`);

  // Test email service connection
  console.log("📧 Testing email service...");
  await emailService.testConnection();

  console.log("✅ Server initialization complete\n");
});
