require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar CORS para permitir solicitudes desde tu dominio específico
app.use(
  cors({
    origin: "https://appenitaxiusuarios.web.app", // Sustituye por el dominio de tu app
    methods: "GET,POST",
    allowedHeaders: "Content-Type",
  })
);

// Ruta del proxy
app.get("/proxyPlacesAPI", async (req, res) => {
  const input = req.query.input;
  const placeId = req.query.place_id;

  if (!input && !placeId) {
    return res.status(400).json({ error: "Falta el parámetro 'input' o 'place_id'" });
  }

  const url = input
    ? `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${process.env.PLACES_API_KEY}`
    : `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&key=${process.env.PLACES_API_KEY}`;

  try {
    const response = await axios.get(url);
    res.setHeader("Access-Control-Allow-Origin", "https://appenitaxiusuarios.web.app"); // Permitir solicitudes desde tu dominio
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.json(response.data);
  } catch (error) {
    console.error("Error al realizar la solicitud a Google Places API:", error.message);
    res.status(500).json({ error: "Error interno del servidor" });
  }
});

// Iniciar el servidor
app.listen(PORT, () => {
  console.log(`Proxy ejecutándose en http://localhost:${PORT}`);
});

module.exports = app;