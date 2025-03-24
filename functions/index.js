const functions = require("firebase-functions");
const fetch = require("node-fetch");

const apiKey = process.env.FIREBASE_API_KEY ||
"AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k";

exports.googlePlacesProxy = functions.https.onRequest(async (req, res) => {
  const origin = req.headers.origin || "*";

  // ✅ Manejo explícito de la preflight request
  if (req.method === "OPTIONS") {
    res.set({
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "3600",
    });
    return res.status(204).send("");
  }

  try {
    const path = req.path; // ejemplo: /place/autocomplete/json
    const query = req.query;

    const baseUrl = "https://maps.googleapis.com/maps/api";
    const fullUrl = `${baseUrl}${path}?${new URLSearchParams({
      ...query,
      key: apiKey,
    }).toString()}`;

    const response = await fetch(fullUrl);
    const data = await response.json();

    res.set("Access-Control-Allow-Origin", origin);
    return res.status(200).json(data);
  } catch (error) {
    console.error("Proxy error:", error);
    res.set("Access-Control-Allow-Origin", origin);
    return res.status(500).json({error: "Error proxying request"});
  }
});
