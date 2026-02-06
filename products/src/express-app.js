const express = require("express");
const cors = require("cors");
const path = require("path");
const { products, appEvents } = require("./api");
const { CreateChannel } = require("./utils");

module.exports = async (app) => {
  app.use(express.json());
  app.use(cors());

  // 🔪 Middleware "Stripper" – removes /products prefix
  app.use((req, res, next) => {
    const prefix = "/products";
    if (req.url.startsWith(prefix)) {
      req.url = req.url.slice(prefix.length) || "/";
      // Example: /products/health → /health
    }
    next();
  });

  // Health check
  app.get("/health", (req, res) => {
    return res
      .status(200)
      .json({ status: "UP", service: "Products Service" });
  });

  // Static files
  app.use(express.static(__dirname + "/public"));

  // API events (optional)
  // appEvents(app);

  const channel = await CreateChannel();

  // Product routes
  products(app, channel);

  // error handling (if needed later)
};
