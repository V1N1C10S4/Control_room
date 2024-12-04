const {onRequest} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const axios = require("axios");

// Configuración global para región e instancias mínimas
setGlobalOptions({
  region: "us-central1",
  minInstances: 1,
});

exports.proxyPlacesAPI = onRequest({
  cors: true, // Habilita CORS automáticamente
  concurrency: 1, // Simula comportamiento de 1ª generación
}, async (req, res) => {
  const input = req.query.input || "";
  const apiKey = "AIzaSyCJycpIn0CzrANDmkUj2I2xok6BhMk-y8g";
  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

  try {
    const response = await axios.get(url);
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET");
    res.status(response.status).send(response.data);
  } catch (error) {
    res.status(error.response?.status || 500).send({
      error: error.message,
    });
  }
});
