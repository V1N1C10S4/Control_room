require("dotenv").config(); // Cargar variables de entorno desde el archivo .env

const express = require("express");
const axios = require("axios");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3000;

// Habilitar CORS para manejar problemas de solicitudes entre dominios
app.use(cors());

// Ruta para el proxy
app.get("/proxyPlacesAPI", async (req, res) => {
  const input = req.query.input || ""; // Obtener el parámetro de consulta

  // Leer la API key desde las variables de entorno
  const apiKey = process.env.PLACES_API_KEY;

  // URL de la API de Google Places
  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

  try {
    // Hacer la solicitud a la API de Google Places
    const response = await axios.get(url);
    res.status(200).json(response.data); // Enviar la respuesta al cliente
  } catch (error) {
    console.error("Error en el proxy:", error.message);
    res.status(error.response?.status || 500).json({
      error: "Error al procesar la solicitud",
    });
  }
});

// Iniciar el servidor
app.listen(PORT, () => {
  console.log(`Proxy ejecutándose en http://localhost:${PORT}`);
});

module.exports = app;