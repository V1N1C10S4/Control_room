const {onRequest} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const axios = require("axios");

// Configuración global para región e instancias mínimas
setGlobalOptions({
  region: "us-central1", // Asegura que está en la misma región que tu proyecto
  minInstances: 0, // Reduce el costo si no necesitas instancias mínimas
});

exports.proxyPlacesAPI = onRequest({
  cors: true, // Habilita CORS automáticamente
  concurrency: 1, // Simula comportamiento de 1ª generación
}, async (req, res) => {
  const input = req.query.input || "";

  // Usa una variable de entorno para tu API key
  const apiKey = process.env.PLACES_API_KEY;
  if (!apiKey) {
    res.status(500).send({error: "API Key no configurada correctamente."});
    return;
  }

  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

  try {
    // Llamada a la API de Google Places
    const response = await axios.get(url);

    res.status(response.status).send(response.data);
  } catch (error) {
    console.error("Error al llamar a Google Places API:", error.message);
    res.status(error.response?.status || 500).send({
      error: "Error al obtener datos de Google Places API.",
    });
  }
});
