const express = require('express');
const cors  = require('cors');
const path = require('path');
const { shopping, appEvents } = require('./api');
const { CreateChannel } = require('./utils');

module.exports = async (app) => {

    app.use(express.json());
    app.use(cors());

    // 🔪 Middleware "Stripper" – removes /shopping prefix
    app.use((req, res, next) => {
        const prefix = '/shopping';
        if (req.url.startsWith(prefix)) {
            req.url = req.url.slice(prefix.length) || '/';
            // Example: /shopping/health → /health
        }
        next();
    });

    // Health check
    app.get('/health', (req, res) => {
        return res.status(200).json({ status: 'UP' });
    });

    // Static files
    app.use(express.static(__dirname + '/public'));

    // API events (optional)
    // appEvents(app);

    const channel = await CreateChannel();

    // Shopping routes
    shopping(app, channel);

    // error handling (if added later)
};
