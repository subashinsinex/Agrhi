// utils/imageCompressor.js
const sharp = require("sharp");
const fs = require("fs");

async function compressImageInPlace(fullPath, options = {}) {
  const { width = 1024, quality = 70 } = options;

  const tempPath = fullPath + ".tmp";

  await sharp(fullPath)
    .resize({ width, withoutEnlargement: true })
    .jpeg({ quality })
    .toFile(tempPath);

  fs.unlinkSync(fullPath);
  fs.renameSync(tempPath, fullPath);
}

module.exports = { compressImageInPlace };
