const logger = require("./logger");
const sharp = require("sharp");
const fs = require("fs");

// Image compression service
async function compressImageInPlace(fullPath, options = {}) {
  const { width = 1024, quality = 70 } = options;
  const tempPath = fullPath + ".tmp";

  try {
    logger.info(
      `Compressing image: ${fullPath} (${width}x, quality:${quality})`,
    );

    await sharp(fullPath)
      .resize({ width, withoutEnlargement: true })
      .jpeg({ quality })
      .toFile(tempPath);

    fs.unlinkSync(fullPath);
    fs.renameSync(tempPath, fullPath);

    logger.info(`Image compressed successfully: ${fullPath}`);
  } catch (error) {
    logger.error("Image compression failed:", fullPath, error.message);
    // Cleanup temp file on error
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
    throw error;
  }
}

module.exports = { compressImageInPlace };
