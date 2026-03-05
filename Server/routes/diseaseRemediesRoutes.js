const express = require("express");
const router = express.Router();
const diseaseRemediesServices = require("../services/diseaseRemediesServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Disease CRUD routes
router.get("/diseases", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.getDiseases();
    res.json(data);
  } catch (error) {
    logger.error("GET /diseases - Error:", error);
    res.status(500).json({ message: "Error fetching diseases" });
  }
});

router.post("/creatediseases", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.createDisease(req.body);
    res.status(201).json(data);
  } catch (error) {
    logger.error("POST /creatediseases - Error:", error);
    res.status(500).json({ message: "Error creating disease" });
  }
});

router.put(
  "/updatediseases/:diseaseid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const data = await diseaseRemediesServices.updateDisease(
        req.params.diseaseid,
        req.body,
      );
      res.json(data);
    } catch (error) {
      logger.error("PUT /updatediseases/:diseaseid - Error:", {
        diseaseid: req.params.diseaseid,
        error,
      });
      res.status(500).json({ message: "Error updating disease" });
    }
  },
);

router.delete(
  "/deletediseases/:diseaseid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const data = await diseaseRemediesServices.deleteDisease(
        req.params.diseaseid,
      );
      res.json(data);
    } catch (error) {
      logger.error("DELETE /deletediseases/:diseaseid - Error:", {
        diseaseid: req.params.diseaseid,
        error,
      });
      res.status(500).json({ message: "Error deleting disease" });
    }
  },
);

// Remedy CRUD routes
router.get("/remedies", jwtChecker, async (req, res) => {
  
  try {
    const remedies = await diseaseRemediesServices.getRemedies();
    res.json(remedies);
  } catch (error) {
    logger.error("GET /remedies - Error:", error);
    res.status(500).json({ message: "Error fetching remedies" });
  }
});

router.post("/createremedies", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const result = await diseaseRemediesServices.createRemedy(req.body);
    res.status(201).json(result);
  } catch (error) {
    logger.error("POST /createremedies - Error:", error);
    res.status(500).json({ message: "Error creating remedy" });
  }
});

router.put(
  "/updateremedies/:remedyid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const result = await diseaseRemediesServices.updateRemedy(
        req.params.remedyid,
        req.body,
      );
      res.json(result);
    } catch (error) {
      logger.error("PUT /updateremedies/:remedyid - Error:", {
        remedyid: req.params.remedyid,
        error,
      });
      res.status(500).json({ message: "Error updating remedy" });
    }
  },
);

router.delete(
  "/deleteremedies/:remedyid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const result = await diseaseRemediesServices.deleteRemedy(
        req.params.remedyid,
      );
      res.json(result);
    } catch (error) {
      logger.error("DELETE /deleteremedies/:remedyid - Error:", {
        remedyid: req.params.remedyid,
        error,
      });
      res.status(500).json({ message: "Error deleting remedy" });
    }
  },
);

// Disease-remedy mapping routes
router.post("/remedies/map", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const { disease_id, remedy_id } = req.body;
    const result = await diseaseRemediesServices.mapRemedyToDisease(
      disease_id,
      remedy_id,
    );
    res.status(201).json(result);
  } catch (error) {
    logger.error("POST /remedies/map - Error:", error);
    res.status(500).json({ message: "Error mapping remedy to disease" });
  }
});

router.delete("/remedies/unmap", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const { disease_id, remedy_id } = req.body;
    const result = await diseaseRemediesServices.unmapRemedyFromDisease(
      disease_id,
      remedy_id,
    );
    res.json(result);
  } catch (error) {
    logger.error("DELETE /remedies/unmap - Error:", error);
    res.status(500).json({ message: "Error unmapping remedy from disease" });
  }
});

router.get("/diseases/:diseaseid/remedies", jwtChecker, async (req, res) => {
  
  try {
    const remedies = await diseaseRemediesServices.getRemediesByDisease(
      req.params.diseaseid,
    );
    res.json(remedies);
  } catch (error) {
    logger.error("GET /diseases/:diseaseid/remedies - Error:", {
      diseaseid: req.params.diseaseid,
      error,
    });
    res.status(500).json({ message: "Error fetching remedies for disease" });
  }
});

router.get("/diseaseswithremedies", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.getAllDiseasesWithRemedies();
    res.json(data);
  } catch (error) {
    logger.error("GET /diseaseswithremedies - Error:", error);
    res.status(500).json({ message: "Error fetching diseases with remedies" });
  }
});

router.get("/diseases/:disease_id/plants", jwtChecker, async (req, res) => {
  
  try {
    const rows = await diseaseRemediesServices.getPlantsForDisease(
      req.params.disease_id,
    );
    res.json(rows);
  } catch (error) {
    logger.error("GET /diseases/:disease_id/plants - Error:", {
      disease_id: req.params.disease_id,
      error,
    });
    res.status(500).json({ message: "Error fetching disease plants" });
  }
});

// Image read route
router.get("/images", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.getImages();
    res.json(data);
  } catch (error) {
    logger.error("GET /images - Error:", error);
    res.status(500).json({ message: "Error fetching images" });
  }
});

// Disease analysis result routes
router.get("/disease-analysis-results", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.getDiseaseAnalysisResults(
      req.query,
    );
    res.json(data);
  } catch (error) {
    logger.error("GET /disease-analysis-results - Error:", error);
    res.status(500).json({ message: "Error fetching analysis results" });
  }
});

router.post("/createdisease-analysis-results", jwtChecker, async (req, res) => {
  
  try {
    const result = await diseaseRemediesServices.createDiseaseAnalysisResult(
      req.body,
    );
    res.status(201).json(result);
  } catch (error) {
    logger.error("POST /createdisease-analysis-results - Error:", error);
    res.status(500).json({ message: "Error creating disease analysis result" });
  }
});

// Junction table read routes
router.get("/disease-remedies", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.diseaseRemedy();
    res.json(data);
  } catch (error) {
    logger.error("GET /disease-remedies - Error:", error);
    res.status(500).json({ message: "Error fetching disease remedies" });
  }
});

router.get("/disease-plants", jwtChecker, async (req, res) => {
  
  try {
    const data = await diseaseRemediesServices.diseasePlants();
    res.json(data);
  } catch (error) {
    logger.error("GET /disease-plants - Error:", error);
    res.status(500).json({ message: "Error fetching disease plants" });
  }
});

module.exports = router;
