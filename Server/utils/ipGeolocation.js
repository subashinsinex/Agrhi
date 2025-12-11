// utils/ipGeolocation.js

const axios = require("axios");

/**
 * Get location from IP address using free API
 * Using freeipapi.com (no limit on free tier)
 */
async function getLocationFromIP(ipAddress) {
  try {
    // Clean IPv6 prefix if present (::ffff:123.45.67.89 -> 123.45.67.89)
    let cleanIp = ipAddress;
    if (ipAddress && ipAddress.includes("::ffff:")) {
      cleanIp = ipAddress.split("::ffff:")[1];
    }

    // Handle localhost/private IPs
    if (
      cleanIp === "::1" ||
      cleanIp === "127.0.0.1" ||
      cleanIp.startsWith("192.168.") ||
      cleanIp.startsWith("10.") ||
      cleanIp.startsWith("172.16.") ||
      cleanIp.startsWith("172.31.")
    ) {
      return "Local Network";
    }

    const response = await axios.get(
      `https://free.freeipapi.com/api/json/${cleanIp}`,
      {
        timeout: 3000,
      }
    );

    const { cityName, regionName, countryName } = response.data;

    const parts = [];
    if (cityName) parts.push(cityName);
    if (regionName) parts.push(regionName);
    if (countryName) parts.push(countryName);

    return parts.length > 0 ? parts.join(", ") : "Unknown Location";
  } catch (error) {
    console.error("Geolocation API error:", error.message);
    return "Unknown Location";
  }
}

module.exports = { getLocationFromIP };
