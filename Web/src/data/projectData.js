// Sources: Official AGRHI project, consortium and Erasmus+ pages (agrhi.com).
// App architecture: Official AGRHI application page (app.agrhi.com).
export const officialLinks = {
  project: "https://www.agrhi.com/",
  consortium: "https://www.agrhi.com/participating-institutions-2",
  erasmus: "https://www.agrhi.com/erasmus",
  application: "https://app.agrhi.com/",
  euProgramme: "https://erasmus-plus.ec.europa.eu/",
};

export const projectFacts = [
  ["Programme", "Erasmus+"],
  ["Action", "Capacity Building in Higher Education"],
  ["Topic", "CBHE — Strand 2"],
  ["Project number", "101128059"],
  ["Coordinator", "VIT Chennai"],
];

export const pillars = [
  ["01", "Agricultural education", "Curricula, teaching practice and applied learning can equip graduates for agriculture shaped by climate pressure, data and new production systems. AGRHI links disciplinary knowledge with practical agricultural needs."],
  ["02", "Digital transformation", "Digital competence is treated as a capability, not simply access to equipment. Learners and educators need to understand how data is collected, interpreted and translated into responsible decisions."],
  ["03", "Sustainable agriculture", "Technology is placed in the context of resource stewardship, resilient production and environmental awareness. The aim is to help people evaluate trade-offs rather than promise automatic outcomes."],
  ["04", "Technology transfer", "Demonstrations, workshops, open learning and field engagement create routes through which university knowledge can become understandable and useful beyond the campus."],
  ["05", "International collaboration", "Asian and European partners bring different agricultural environments, research traditions and technical strengths into a shared programme of capacity building."],
  ["06", "Community empowerment", "Farmer participation and access for rural and under-served learners keep innovation connected to the people expected to use it."],
];

export const partners = [
  { country: "India", institutions: ["Vellore Institute of Technology, Chennai", "Anna University, Chennai", "COEP Technological University", "Arcedus Technologies India"] },
  { country: "Sri Lanka", institutions: ["University of Jaffna", "Eastern University, Sri Lanka"] },
  { country: "Malaysia", institutions: ["Asia Pacific University of Technology & Innovation", "Universiti Malaysia Pahang Al-Sultan Abdullah"] },
  { country: "Greece", institutions: ["University of West Attica"] },
  { country: "Poland", institutions: ["Institute of Fluid-Flow Machinery, Polish Academy of Sciences"] },
  { country: "Türkiye", institutions: ["Middle East Technical University"] },
];

export const events = [
  { year: "2024", title: "ICDTSA 2024", place: "VIT Chennai, India", type: "International conference", text: "Research exchange around precision agriculture, AI applications, sustainable farming, urban agriculture and agri-entrepreneurship." },
  { year: "2024", title: "Smart Farming: AI-Driven Solutions", place: "Anna University, India", type: "Pre-conference workshop", text: "A practical learning format connecting smart-farming concepts with AI-enabled agricultural tools." },
  { year: "2025", title: "RATT — Tech-Driven Agriculture", place: "VIT Chennai, India", type: "Regional training", text: "Two days of sessions and demonstrations covering UAVs, autonomous systems, geospatial tools, remote sensing, farm equipment and weather stations." },
  { year: "2025", title: "ICDTSA 2025", place: "Eastern University, Sri Lanka", type: "International conference", text: "The second conference continued exchange on digital technologies for sustainable agriculture." },
  { year: "2025–26", title: "EUSAT activities", place: "Partner institutions", type: "International workshops", text: "University-hosted knowledge exchange connecting institutional practice, smart farming, training and applied technology." },
  { year: "2026", title: "EUSAT UOJ", place: "University of Jaffna, Sri Lanka", type: "Knowledge exchange", text: "A programme of technical sessions, agri-entrepreneur experience sharing, facility and farm visits, and discussions linking research with practice." },
];

export const appComponents = [
  ["Mobile field layer", "A Flutter mobile application supports offline-first farm planning and crop management, designed for work where connectivity is intermittent."],
  ["Local data layer", "SQLite keeps essential workflows and records available on the device. Data can be synchronized when a connection becomes available."],
  ["Intelligence layer", "Python and TensorFlow models support image-based crop disease identification and contextual decision support."],
  ["Web and operations layer", "A PERN-based portal supports administration, data tracking and analysis, alongside operational and resource-management tools."],
];

export const technologies = [
  ["AI & computer vision", "Learners can explore how plant images become model inputs, predictions and evidence that still requires agricultural interpretation."],
  ["IoT & field sensors", "Weather, soil, humidity, temperature, pH and EC sensing make changing field conditions observable and suitable for analysis."],
  ["Remote sensing & drones", "Aerial and multispectral observations can support crop monitoring, mapping and precision-agriculture research."],
  ["Hydroponics & dosing", "Automated hydroponic and IoT dosing systems provide a controlled setting for studying nutrients, water and feedback-driven operation."],
  ["Robotics & automation", "Mobile and autonomous platforms let teams examine navigation, field operations, safety and the practical limits of automation."],
  ["Agricultural analytics", "Data workflows help students move from isolated readings to trends, questions, visual evidence and better-informed action."],
];

export const euDisclaimer = "The European Commission's support for the production of this publication does not constitute an endorsement of the contents, which reflect the views only of the authors, and the Commission cannot be held responsible for any use which may be made of the information contained therein.";
