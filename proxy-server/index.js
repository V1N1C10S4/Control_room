require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar CORS para permitir todas las solicitudes
app.use(cors());

app.get("/proxyPlacesAPI", async (req, res) => {
    const input = req.query.input || "";
    const apiKey = process.env.PLACES_API_KEY;

    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${apiKey}`;

    try {
        const response = await axios.get(url);
        res.setHeader("Access-Control-Allow-Origin", "*");
        res.json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({
            error: error.message,
        });
    }
});

app.listen(PORT, () => {
    console.log(`Proxy ejecutándose en http://localhost:${PORT}`);
});

module.exports = app;