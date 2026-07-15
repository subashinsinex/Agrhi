const express = require("express");
const router = express.Router();
const farmCropService = require("../services/farmCropServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Farm CRUD routes
router.get("/farms", jwtChecker, adminChecker, (req, res, next) => {
  
  farmCropService.getAllFarms(req, res, next);
});

router.get("/farms/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.getFarmById(req, res, next);
});

router.get("/farms/:id/options", (req, res, next) => {
  
  farmCropService.getFarmCropOptions(req, res, next);
});

router.post("/addfarms", jwtChecker, (req, res, next) => {
  
  farmCropService.addFarm(req, res, next);
});

router.post("/addfarmsbyid", jwtChecker, (req, res, next) => {
  
  farmCropService.addFarmByUserId(req, res, next);
});

router.put("/updatefarms/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.updateFarm(req, res, next);
});

router.put("/isdeletefarms/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.isdeleteFarm(req, res, next);
});

router.delete(
  "/deletefarms/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteFarm(req, res, next);
  },
);

// Crop CRUD routes
router.get("/crops", jwtChecker, adminChecker, (req, res, next) => {
  
  farmCropService.getAllCrops(req, res, next);
});

router.get("/crops/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.getCropById(req, res, next);
});

router.get("/crophistory/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.getCropHistoryById(req, res, next);
});

router.post("/addcrops", jwtChecker, (req, res, next) => {
  
  farmCropService.addCrop(req, res, next);
});

router.put("/updatecrops/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.updateCrop(req, res, next);
});

router.put("/isdeletecrops/:id", jwtChecker, (req, res, next) => {
  
  farmCropService.isdeleteCrop(req, res, next);
});

router.delete(
  "/deletecrops/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteCrop(req, res, next);
  },
);

// Master table read routes
router.get("/masters/soiltypes", jwtChecker, (req, res, next) => {
  
  farmCropService.getSoilTypes(req, res, next);
});

router.get("/masters/irrigations", jwtChecker, (req, res, next) => {
  
  farmCropService.getIrrigations(req, res, next);
});

router.get("/masters/watersources", jwtChecker, (req, res, next) => {
  
  farmCropService.getWaterSources(req, res, next);
});

router.get("/masters/croptypes", jwtChecker, (req, res, next) => {
  
  farmCropService.getCropTypes(req, res, next);
});

router.get("/masters/plants", jwtChecker, (req, res, next) => {
  
  farmCropService.getPlants(req, res, next);
});

// Master table add routes (admin only)
router.post(
  "/masters/addsoiltypes",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.addSoilType(req, res, next);
  },
);

router.post(
  "/masters/addirrigations",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.addIrrigation(req, res, next);
  },
);

router.post(
  "/masters/addwatersources",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.addWaterSource(req, res, next);
  },
);

router.post(
  "/masters/addcroptypes",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.addCropType(req, res, next);
  },
);

router.post(
  "/masters/addplants",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.addPlant(req, res, next);
  },
);

// Master table delete routes (admin only)
router.delete(
  "/masters/deletesoiltypes/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteSoilType(req, res, next);
  },
);

router.delete(
  "/masters/deleteirrigations/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteIrrigation(req, res, next);
  },
);

router.delete(
  "/masters/deletewatersources/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteWaterSource(req, res, next);
  },
);

router.delete(
  "/masters/deletecroptypes/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deleteCropType(req, res, next);
  },
);

router.delete(
  "/masters/deleteplants/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    farmCropService.deletePlant(req, res, next);
  },
);

module.exports = router;
