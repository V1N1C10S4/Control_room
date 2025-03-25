const functions = require("firebase-functions");
const fetch = require("node-fetch");

// ✅ Usa variable de entorno segura o clave directa
const apiKey = process.env.FIREBASE_API_KEY ||
"AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k";

// ✅ Cloud Function HTTPS
exports.googlePlacesProxy = functions.https.onRequest(async (req, res) => {
  const origin = req.headers.origin || "https://appenitaxiusuarios.web.app";

  // ✅ Headers comunes para todas las respuestas
  res.set({
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin", // 👉 mejora compatibilidad con múltiples orígenes
  });

  // ✅ Manejo de solicitud preflight (OPTIONS)
  if (req.method === "OPTIONS") {
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

    return res.status(200).json(data);
  } catch (error) {
    console.error("Proxy error:", error);
    return res.status(500).json({error: "Error proxying request"});
  }
});
