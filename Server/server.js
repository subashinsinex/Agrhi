require("dotenv").config();
const express = require("express");
const cors = require("cors");
const app = express();
app.use(cors());
app.use(express.json());

const loginRoutes = require("./routes/loginRoutes");
const userRoutes = require("./routes/userManageRoutes");
const subsidiesRoutes = require("./routes/subsidiesRoutes");
const farmCropRoutes = require("./routes/farmCropRoutes");
const diseaseRemediesRoutes = require("./routes/diseaseRemediesRoutes");

app.use("/api/login", loginRoutes);
app.use("/api/users", userRoutes);
app.use("/api/subsidies", subsidiesRoutes);
app.use("/api/farmcrop", farmCropRoutes);
app.use("/api/diseaseRemedies", diseaseRemediesRoutes);

const PORT = process.env.PORT;

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
