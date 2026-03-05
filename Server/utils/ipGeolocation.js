const logger = require("./logger");
const axios = require("axios");

// IP geolocation service
async function getLocationFromIP(ipAddress) {
  try {
    let cleanIp = ipAddress;
    if (ipAddress && ipAddress.includes("::ffff:")) {
      cleanIp = ipAddress.split("::ffff:")[1];
    }

    if (
      cleanIp === "::1" ||
      cleanIp === "127.0.0.1" ||
      cleanIp.startsWith("192.168.") ||
      cleanIp.startsWith("10.") ||
      cleanIp.startsWith("172.16.") ||
      cleanIp.startsWith("172.31.")
    ) {
      logger.info(`IP ${cleanIp} → Local Network`);
      return "Local Network";
    }

    logger.info(`Geolocation lookup for IP: ${cleanIp}`);

    const response = await axios.get(
      `https://free.freeipapi.com/api/json/${cleanIp}`,
      {
        timeout: 3000,
      },
    );

    const { cityName, regionName, countryName } = response.data;

    const parts = [];
    if (cityName) parts.push(cityName);
    if (regionName) parts.push(regionName);
    if (countryName) parts.push(countryName);

    const location = parts.length > 0 ? parts.join(", ") : "Unknown Location";
    logger.info(`IP ${cleanIp} → ${location}`);
    return location;
  } catch (error) {
    logger.error("Geolocation API error:", error.message);
    return "Unknown Location";
  }
}

module.exports = { getLocationFromIP };
