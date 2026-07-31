require("dotenv").config();

const express = require("express");
const cors = require("cors");
const requestIp = require("request-ip");
const path = require("path");
const { spawn } = require("child_process");

const { asyncLocalStorage } = require("./db/database");
const logger = require("./utils/logger");
const httpLogger = require("./middleware/httpLogger");
const emailService = require("./utils/emailSender");

const app = express();

const PYTHON_CMD = process.platform === "win32" ? "python" : "python3";

const embeddingProcess = spawn(
  PYTHON_CMD,
  [
    "-m",
    "uvicorn",
    "embedding_service:app",
    "--host",
    "0.0.0.0",
    "--port",
    "8001",
  ],
  {
    cwd: path.join(__dirname, "services"),
    stdio: "inherit",
    env: {
      ...process.env,
      HF_TOKEN: process.env.HF_TOKEN,
    },
  },
);

embeddingProcess.on("spawn", () => {
  console.log("[Embedding Service] Started on port 8001");
});

embeddingProcess.on("error", (err) => {
  console.error("[Embedding Service] Failed to start:", err.message);
});

embeddingProcess.on("exit", (code, signal) => {
  console.log(
    `[Embedding Service] Exited with code ${code ?? "null"} and signal ${signal ?? "null"}`,
  );
});

const shutdown = () => {
  if (embeddingProcess && !embeddingProcess.killed) {
    embeddingProcess.kill();
  }
  process.exit(0);
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

app.set("trust proxy", true);

app.use((req, res, next) => asyncLocalStorage.run({ userId: null }, next));

app.use(cors());
app.use(express.json());
app.use(requestIp.mw());
app.use(httpLogger);

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
const developerRoutes = require("./routes/developerRoutes");
const farmStoreRoutes = require("./routes/farmStoreRoutes");
const retailManagementRoutes = require("./routes/retailManagementRoutes");
const marketPlaceRoutes = require("./routes/marketPlaceRoutes");
const shopImageRoutes = require("./routes/shopImageRoutes");
const productImageRoutes = require("./routes/productImageRoutes");
const aiChatRoutes = require("./routes/aiChatRoutes");
const communityRoutes = require("./routes/communityRoutes");

// AI Chatbot route
app.use("/api/chatbot", aiChatRoutes);

app.use("/api/shop-images", shopImageRoutes);
app.use("/api/product-images", productImageRoutes);
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
app.use("/api/community", communityRoutes);

// Static files
app.use("/uploads", express.static(path.join(__dirname, "uploads")));
app.use("/models", express.static(path.join(__dirname, "models")));

const PORT = process.env.PORT || 5000;

app.listen(PORT, async () => {
  logger.server(`Server started on port ${PORT}`);
  await emailService.testConnection();
  logger.server("All services initialized — ready to handle requests");
});
