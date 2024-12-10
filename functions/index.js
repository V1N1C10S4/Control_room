const {onRequest} = require("firebase-functions/v2/https");
const axios = require("axios");

exports.proxyPlacesAPI = onRequest({
  cors: true, // Habilita CORS automáticamente
}, async (req, res) => {
  const input = req.query.input || "";

  // Configurar la API Key como variable de entorno
  const apiKey = process.env.PLACES_API_KEY || "YOUR_API_KEY";
  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

  try {
    const response = await axios.get(url);

    // Opcional: Encabezados CORS adicionales
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");

    res.status(response.status).send(response.data);
  } catch (error) {
    res.status(error.response?.status || 500).send({
      error: error.message || "Error al procesar la solicitud",
    });
  }
});
