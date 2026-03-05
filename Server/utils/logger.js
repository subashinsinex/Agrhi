const fs = require("fs");
const path = require("path");
const XLSX = require("xlsx");

// Paths + config
const logDir = path.join(__dirname, "../logs");
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

const WRITE_INTERVAL = 5000;
const MAX_RETRY_ATTEMPTS = 3;
const RETRY_DELAY = 1000;

// Buffer state
let logBuffer = {
  date: getISTDate(),
  logs: [],
  writing: false,
  writeTimer: null,
};

// Time helpers (IST)
function getISTTime() {
  return new Date(Date.now() + 5.5 * 60 * 60 * 1000)
    .toISOString()
    .slice(11, 19);
}

function getISTDate() {
  return new Date(Date.now() + 5.5 * 60 * 60 * 1000)
    .toISOString()
    .split("T")[0];
}

// Daily log file paths
function getLogPaths() {
  const today = getISTDate();
  return {
    appLog: path.join(logDir, `app-${today}.log`),
    errorLog: path.join(logDir, `errors-${today}.log`),
    excelLog: path.join(logDir, `app-${today}.xlsx`),
    tempExcel: path.join(logDir, `app-${today}.tmp.xlsx`),
  };
}

// File lock check
function isFileLocked(filePath) {
  try {
    const fd = fs.openSync(filePath, "r+");
    fs.closeSync(fd);
    return false;
  } catch (err) {
    return err.code === "EBUSY" || err.code === "EPERM";
  }
}

// Read existing Excel rows
function readExistingLogs(excelPath) {
  try {
    if (!fs.existsSync(excelPath)) return [];
    const workbook = XLSX.readFile(excelPath);
    const worksheet = workbook.Sheets["Logs"];
    if (!worksheet) return [];
    return XLSX.utils.sheet_to_json(worksheet);
  } catch (error) {
    console.error("Failed to read existing Excel:", error.message);
    return [];
  }
}

// Write buffered logs to Excel
async function writeToExcel(attempt = 1) {
  if (logBuffer.writing) return;

  const currentDate = getISTDate();
  if (logBuffer.date !== currentDate) {
    logBuffer = {
      date: currentDate,
      logs: [],
      writing: false,
      writeTimer: null,
    };
    return;
  }

  if (logBuffer.logs.length === 0) return;

  logBuffer.writing = true;

  try {
    const { excelLog, tempExcel } = getLogPaths();

    if (fs.existsSync(excelLog) && isFileLocked(excelLog)) {
      console.warn(
        `[Excel Logger] File is locked (Excel is open). Logs queued: ${logBuffer.logs.length}. Will retry in ${RETRY_DELAY}ms...`,
      );
      logBuffer.writing = false;

      if (attempt < MAX_RETRY_ATTEMPTS) {
        setTimeout(() => writeToExcel(attempt + 1), RETRY_DELAY);
      } else {
        console.warn(
          `[Excel Logger] Max retries reached. ${logBuffer.logs.length} logs buffered. Will try next cycle.`,
        );
      }
      return;
    }

    const existingLogs = readExistingLogs(excelLog);
    const allLogs = [...existingLogs, ...logBuffer.logs];

    // Excel columns (HTTP-only, no message)
    const columns = [
      "date",
      "timestamp",
      "method",
      "endpoint",
      "status_code",
      "duration_ms",
      "user_id",
      "ip_address",
      "user_agent",
    ];

    const wsData = [columns];
    for (const log of allLogs) {
      const row = columns.map((col) => {
        const value = log[col];
        return value !== null && value !== undefined ? value : "";
      });
      wsData.push(row);
    }

    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.aoa_to_sheet(wsData);

    ws["!cols"] = [
      { wch: 12 },
      { wch: 10 },
      { wch: 8 },
      { wch: 40 },
      { wch: 12 },
      { wch: 12 },
      { wch: 18 },
      { wch: 16 },
      { wch: 40 },
    ];

    XLSX.utils.book_append_sheet(wb, ws, "Logs");
    XLSX.writeFile(wb, tempExcel);
    fs.renameSync(tempExcel, excelLog);

    const writtenCount = logBuffer.logs.length;
    console.log(
      `[Excel Logger] ✓ Wrote ${writtenCount} log(s) to Excel (Total: ${allLogs.length})`,
    );

    logBuffer.logs = [];
    logBuffer.writing = false;
  } catch (error) {
    console.error("[Excel Logger] Failed to write to Excel:", error.message);
    logBuffer.writing = false;

    if (attempt < MAX_RETRY_ATTEMPTS) {
      setTimeout(() => writeToExcel(attempt + 1), RETRY_DELAY);
    }
  }
}

// Buffer an HTTP log row
function bufferHttpLog(logEntry) {
  const currentDate = getISTDate();
  if (logBuffer.date !== currentDate) {
    logBuffer = {
      date: currentDate,
      logs: [],
      writing: false,
      writeTimer: null,
    };
  }

  logBuffer.logs.push(logEntry);

  if (!logBuffer.writeTimer) {
    logBuffer.writeTimer = setTimeout(() => {
      logBuffer.writeTimer = null;
      writeToExcel();
    }, WRITE_INTERVAL);
  }
}

// Flush buffered logs
function flushLogs() {
  if (logBuffer.writeTimer) {
    clearTimeout(logBuffer.writeTimer);
    logBuffer.writeTimer = null;
  }
  return writeToExcel();
}

// Format message for text logs
function formatMessage(args) {
  return args
    .map((arg) =>
      typeof arg === "object" ? JSON.stringify(arg, null, 2) : String(arg),
    )
    .join(" ");
}

// Write INFO/WARN/ERROR only to text
function writeTextLog(level, consoleFn, args, writeError = false) {
  const istTime = getISTTime();
  const message = formatMessage(args);
  const line = `[${istTime}] ${level}: ${message}\n`;
  consoleFn(line.trim());

  const { appLog, errorLog } = getLogPaths();
  fs.appendFileSync(appLog, line);
  if (writeError) fs.appendFileSync(errorLog, line);
}

// Public logger
const logger = {
  info: (...args) => writeTextLog("INFO", console.log, args),
  warn: (...args) => writeTextLog("WARN", console.warn, args),
  error: (...args) => writeTextLog("ERROR", console.error, args, true),

  server: (event) => {
    const istTime = getISTTime();
    const line = `[${istTime}] SERVER: ${event}\n`;
    console.log(line.trim());
    fs.appendFileSync(getLogPaths().appLog, line);
  },

  // HTTP-only Excel logging
  http: (data) => {
    const istTime = getISTTime();
    const istDate = getISTDate();

    const line = `[${istTime}] HTTP: ${data.method} ${data.endpoint} | user=${data.user_id || "unauthenticated"} | ip=${data.ip || "unknown"} | agent=${data.user_agent || "unknown"} | status=${data.status_code} | duration=${data.duration_ms}ms\n`;
    console.log(line.trim());
    fs.appendFileSync(getLogPaths().appLog, line);

    bufferHttpLog({
      date: istDate,
      timestamp: istTime,
      method: data.method,
      endpoint: data.endpoint,
      status_code: data.status_code,
      duration_ms: data.duration_ms,
      user_id: data.user_id || "unauthenticated",
      ip_address: data.ip || "unknown",
      user_agent: data.user_agent || "unknown",
    });
  },

  flush: flushLogs,
};

// Shutdown hook
process.on("SIGINT", () => {
  console.log("\n[Excel Logger] Flushing logs before exit...");
  flushLogs();
  setTimeout(() => process.exit(0), 2000);
});

process.on("SIGTERM", () => {
  console.log("\n[Excel Logger] Flushing logs before exit...");
  flushLogs();
  setTimeout(() => process.exit(0), 2000);
});

module.exports = logger;
