const express = require("express");
const router = express.Router();
const farmCropService = require("../services/farmCropServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// router.use(jwtChecker, adminChecker);

// Farms CRUD
router.get("/farms", farmCropService.getAllFarms);
router.get("/farms/:id", farmCropService.getFarmById);
router.post("/addfarms", farmCropService.addFarm);
router.put("/updatefarms/:id", farmCropService.updateFarm);
router.delete("/deletefarms/:id", farmCropService.deleteFarm);

// Crops CRUD
router.get("/crops", farmCropService.getAllCrops);
router.get("/crops/:id", farmCropService.getCropById);
router.post("/addcrops", farmCropService.addCrop);
router.put("/updatecrops/:id", farmCropService.updateCrop);
router.delete("/deletecrops/:id", farmCropService.deleteCrop);

// Master tables
router.get("/masters/soiltypes", farmCropService.getSoilTypes);
router.get("/masters/irrigations", farmCropService.getIrrigations);
router.get("/masters/watersources", farmCropService.getWaterSources);
router.get("/masters/croptypes", farmCropService.getCropTypes);
router.get("/masters/plants", farmCropService.getPlants);

// Add master data (optional, enable as needed)
router.post("/masters/addsoiltypes", farmCropService.addSoilType);
router.post("/masters/addirrigations", farmCropService.addIrrigation);
router.post("/masters/addwatersources", farmCropService.addWaterSource);
router.post("/masters/addcroptypes", farmCropService.addCropType);
router.post("/masters/addplants", farmCropService.addPlant);

// Delete master data
router.delete("/masters/deletesoiltypes/:id", farmCropService.deleteSoilType);
router.delete(
  "/masters/deleteirrigations/:id",
  farmCropService.deleteIrrigation
);
router.delete(
  "/masters/deletewatersources/:id",
  farmCropService.deleteWaterSource
);
router.delete("/masters/deletecroptypes/:id", farmCropService.deleteCropType);
router.delete("/masters/deleteplants/:id", farmCropService.deletePlant);

module.exports = router;
