const express = require("express");
const router = express.Router();
const diseaseRemediesServices = require("../services/diseaseRemediesServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

router.use(jwtChecker, adminChecker);

// --- Diseases CRUD ---
router.get("/diseases", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.getDiseases();
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: "Error fetching diseases" });
  }
});

router.post("/creatediseases", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.createDisease(req.body);
    res.status(201).json(data);
  } catch (error) {
    res.status(500).json({ message: "Error creating disease" });
  }
});

router.put("/updatediseases/:diseaseid", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.updateDisease(
      req.params.diseaseid,
      req.body
    );
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: "Error updating disease" });
  }
});

router.delete("/deletediseases/:diseaseid", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.deleteDisease(
      req.params.diseaseid
    );
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: "Error deleting disease" });
  }
});

// --- Remedy CRUD ---
// GET all remedies (with mapped diseases)
router.get("/remedies", async (req, res) => {
  try {
    const remedies = await diseaseRemediesServices.getRemedies();
    res.json(remedies);
  } catch (error) {
    res.status(500).json({ message: "Error fetching remedies" });
  }
});

// POST create remedy
router.post("/createremedies", async (req, res) => {
  try {
    const newRemedy = req.body; // expects remedy and prevention
    const result = await diseaseRemediesServices.createRemedy(newRemedy);
    res.status(201).json(result);
  } catch (error) {
    res.status(500).json({ message: "Error creating remedy" });
  }
});

// PUT update remedy
router.put("/updateremedies/:remedyid", async (req, res) => {
  try {
    const remedyid = req.params.remedyid;
    const updated = req.body;
    const result = await diseaseRemediesServices.updateRemedy(
      remedyid,
      updated
    );
    res.json(result);
  } catch (error) {
    res.status(500).json({ message: "Error updating remedy" });
  }
});

// DELETE remedy
router.delete("/deleteremedies/:remedyid", async (req, res) => {
  try {
    const remedyid = req.params.remedyid;
    const result = await diseaseRemediesServices.deleteRemedy(remedyid);
    res.json(result);
  } catch (error) {
    res.status(500).json({ message: "Error deleting remedy" });
  }
});

// --- Remedy/Disease Mapping ---
// POST map a remedy to a disease
router.post("/remedies/map", async (req, res) => {
  try {
    const { disease_id, remedy_id } = req.body;
    const result = await diseaseRemediesServices.mapRemedyToDisease(
      disease_id,
      remedy_id
    );
    res.status(201).json(result);
  } catch (error) {
    res.status(500).json({ message: "Error mapping remedy to disease" });
  }
});

// DELETE unmap remedy from disease
router.delete("/remedies/unmap", async (req, res) => {
  try {
    const { diseaseid, remedyid } = req.body;
    const result = await diseaseRemediesServices.unmapRemedyFromDisease(
      diseaseid,
      remedyid
    );
    res.json(result);
  } catch (error) {
    res.status(500).json({ message: "Error unmapping remedy from disease" });
  }
});

// GET remedies mapped to a specific disease
router.get("/diseases/:diseaseid/remedies", async (req, res) => {
  try {
    const diseaseid = req.params.diseaseid;
    const remedies = await diseaseRemediesServices.getRemediesByDisease(
      diseaseid
    );
    res.json(remedies);
  } catch (error) {
    res.status(500).json({ message: "Error fetching remedies for disease" });
  }
});

// --- Images Read ---
router.get("/images", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.getImages();
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: "Error fetching images" });
  }
});

router.post("/addimages", async (req, res) => {
  try {
    const data = await diseaseRemediesServices.addImage(req.body);
    res.status(201).json(data);
  } catch (error) {
    res.status(500).json({ message: "Error adding image" });
  }
});

// --- Disease Analysis Read ---
router.get("/disease-analysis-results", async (req, res) => {
  try {
    const filters = req.query; // e.g. ?diseaseid=1&userid=2
    const data = await diseaseRemediesServices.getDiseaseAnalysisResults(
      filters
    );
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: "Error fetching analysis results" });
  }
});

// POST a new disease analysis result
router.post("/createdisease-analysis-results", async (req, res) => {
  try {
    const payload = req.body;
    const result = await diseaseRemediesServices.createDiseaseAnalysisResult(
      payload
    );
    res.status(201).json(result);
  } catch (error) {
    res.status(500).json({ message: "Error creating disease analysis result" });
  }
});

module.exports = router;
