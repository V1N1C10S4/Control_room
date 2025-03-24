const functions = require("firebase-functions");
const cors = require("cors")({origin: true});
const fetch = require("node-fetch");

const apiKey = process.env.FIREBASE_API_KEY ||
"AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k";

exports.googlePlacesProxy = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const path = req.path; // ejemplo: /geocode/json
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
});
