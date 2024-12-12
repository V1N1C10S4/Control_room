require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar CORS
app.use(
  cors({
    origin: ["https://appenitaxiusuarios.web.app"], // Dominios permitidos
    methods: ["GET"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

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

    // Configurar cabeceras para solicitudes CORS
    res.setHeader("Access-Control-Allow-Origin", "https://appenitaxiusuarios.web.app");
    res.setHeader("Access-Control-Allow-Methods", "GET");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

    res.json(response.data);
  } catch (error) {
    console.error("Error al realizar la solicitud:", error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || "Error interno del servidor",
    });
  }
});

// Iniciar el servidor
app.listen(PORT, () => {
  console.log(`Proxy ejecutándose en http://localhost:${PORT}`);
});

module.exports = app;