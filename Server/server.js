// Server/server.js
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const requestIp = require("request-ip");
const emailService = require("./utils/emailSender");
const path = require("path");

const { asyncLocalStorage } = require("./db/database");
const jwtChecker = require("./middleware/jwtChecker");

const app = express();

// 1) Trust proxy
app.set("trust proxy", true);

// 2) ALS context for every request (FIRST)
app.use((req, res, next) => {
  asyncLocalStorage.run({ userId: null }, () => {
    next();
  });
});

// 3) Core middleware
app.use(cors());
app.use(express.json());
app.use(requestIp.mw());

// 5) Routes
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
const developerRoutes = require("./routes/developerRoutes");
const farmStoreRoutes = require("./routes/farmStoreRoutes");
const retailManagementRoutes = require("./routes/retailManagementRoutes");
const marketPlaceRoutes = require("./routes/marketPlaceRoutes");
const shopImageRoutes = require("./routes/shopImageRoutes");
const productImageRoutes = require("./routes/productImageRoutes");
const aiChatRoutes = require("./routes/aiChatRoutes");

// AI Chatbot route (before jwtChecker because it's /api/chatbot)
app.use("/api/chatbot", aiChatRoutes);

// Image routes (behind jwtChecker because they are /api)
app.use("/api/shop-images", shopImageRoutes);
app.use("/api/product-images", productImageRoutes);

// Other API routes
app.use("/api", loginRoutes);
app.use("/api/users", userRoutes);
app.use("/api/subsidies", subsidiesRoutes);
app.use("/api/farmcrop", farmCropRoutes);
app.use("/api/diseaseRemedies", diseaseRemediesRoutes);
app.use("/api/profile", profileRoutes);
app.use("/api/feedback", feedbackRoutes);
app.use("/api/sync", syncRoutes);
app.use("/api/forgot-password", forgotPasswordRoutes);
app.use("/api/email-verification", emailVerificationRoutes);
app.use("/api/developer", developerRoutes);
app.use("/api/farmstore", farmStoreRoutes);
app.use("/api/retail", retailManagementRoutes);
app.use("/api/marketplace", marketPlaceRoutes);

// Static
app.use("/uploads", express.static(path.join(__dirname, "uploads")));
app.use("/models", express.static("models"));

const PORT = process.env.PORT || 5000;

app.listen(PORT, async () => {
  console.log(`\n🚀 Server is running on port ${PORT}`);
  console.log(`📍 Server URL: http://localhost:${PORT}`);

  console.log("📧 Testing email service...");
  await emailService.testConnection();

  console.log("✅ Server initialization complete\n");
});
