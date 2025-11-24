const express = require("express");
const router = express.Router();
const farmCropService = require("../services/farmCropServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Farms CRUD
router.get("/farms", jwtChecker, adminChecker, farmCropService.getAllFarms);
router.get("/farms/:id", jwtChecker, farmCropService.getFarmById);
router.post("/addfarms", jwtChecker, farmCropService.addFarm);
router.post("/addfarmsbyid", jwtChecker, farmCropService.addFarmByUserId);
router.put("/updatefarms/:id", jwtChecker, farmCropService.updateFarm);
router.delete(
  "/deletefarms/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteFarm
);

// Crops CRUD
router.get("/crops", jwtChecker, adminChecker, farmCropService.getAllCrops);
router.get("/crops/:id", jwtChecker, farmCropService.getCropById);
router.get("/crophistory/:id", jwtChecker, farmCropService.getCropHistoryById);
router.post("/addcrops", jwtChecker, farmCropService.addCrop);
router.put("/updatecrops/:id", jwtChecker, farmCropService.updateCrop);
router.delete(
  "/deletecrops/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteCrop
);

router.get("/farms/:id/options", farmCropService.getFarmCropOptions);

// Master tables
router.get("/masters/soiltypes", jwtChecker, farmCropService.getSoilTypes);
router.get("/masters/irrigations", jwtChecker, farmCropService.getIrrigations);
router.get(
  "/masters/watersources",
  jwtChecker,
  farmCropService.getWaterSources
);
router.get("/masters/croptypes", jwtChecker, farmCropService.getCropTypes);
router.get("/masters/plants", jwtChecker, farmCropService.getPlants);

// Add master data (optional, enable as needed)
router.post(
  "/masters/addsoiltypes",
  jwtChecker,
  adminChecker,
  farmCropService.addSoilType
);
router.post(
  "/masters/addirrigations",
  jwtChecker,
  adminChecker,
  farmCropService.addIrrigation
);
router.post(
  "/masters/addwatersources",
  jwtChecker,
  adminChecker,
  farmCropService.addWaterSource
);
router.post(
  "/masters/addcroptypes",
  jwtChecker,
  adminChecker,
  farmCropService.addCropType
);
router.post(
  "/masters/addplants",
  jwtChecker,
  adminChecker,
  farmCropService.addPlant
);

// Delete master data
router.delete(
  "/masters/deletesoiltypes/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteSoilType
);
router.delete(
  "/masters/deleteirrigations/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteIrrigation
);
router.delete(
  "/masters/deletewatersources/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteWaterSource
);
router.delete(
  "/masters/deletecroptypes/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deleteCropType
);
router.delete(
  "/masters/deleteplants/:id",
  jwtChecker,
  adminChecker,
  farmCropService.deletePlant
);

module.exports = router;
