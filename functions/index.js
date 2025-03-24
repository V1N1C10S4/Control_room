const functions = require("firebase-functions");
const fetch = require("node-fetch");

const apiKey = process.env.FIREBASE_API_KEY ||
"AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k";

exports.googlePlacesProxy = functions.https.onRequest(async (req, res) => {
  // Manejo de preflight
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Max-Age", "3600");
    return res.status(204).send("");
  }

  // Headers CORS para todas las respuestas
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const path = req.path; // Ej: /place/autocomplete/json
    const query = req.query;

    const baseUrl = "https://maps.googleapis.com/maps/api";
    const fullUrl = `${baseUrl}${path}?${new URLSearchParams({
      ...query,
      key: apiKey,
    }).toString()}`;

    const response = await fetch(fullUrl);
    const data = await response.json();

    res.status(200).json(data);
  } catch (error) {
    console.error("Proxy error:", error);
    res.status(500).json({error: "Error proxying request"});
  }
});
