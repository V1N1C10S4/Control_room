const express = require("express");
const axios = require("axios");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3000;

// Habilitar CORS
app.use(cors());

// Ruta para el proxy
app.get("/proxyPlacesAPI", async (req, res) => {
  const input = req.query.input || "";

  const apiKey = process.env.PLACES_API_KEY || "YOUR_API_KEY";

  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

  try {
    const response = await axios.get(url);
    res.status(200).json(response.data);
  } catch (error) {
    console.error("Error en el proxy:", error.message);
    res.status(error.response?.status || 500).json({
      error: "Error al procesar la solicitud",
    });
  }
});

app.listen(PORT, () => {
  console.log(`Proxy ejecutándose en http://localhost:${PORT}`);
});

module.exports = app;