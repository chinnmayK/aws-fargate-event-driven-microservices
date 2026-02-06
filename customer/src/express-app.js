const express = require('express');
const cors  = require('cors');
const { customer, appEvents } = require('./api');
const { CreateChannel, SubscribeMessage } = require('./utils');

module.exports = async (app) => {

    app.use(express.json());
    app.use(cors());

    // 🔪 Middleware "Stripper" – removes /customer prefix
    app.use((req, res, next) => {
        const prefix = '/customer';
        if (req.url.startsWith(prefix)) {
            req.url = req.url.slice(prefix.length) || '/';
            // Example: /customer/health → /health
        }
        next();
    });

    // Health check
    app.get('/health', (req, res) => {
        return res.status(200).json({ status: 'UP' });
    });

    // Static files
    app.use(express.static(__dirname + '/public'));

    // API events (if needed later)
    // appEvents(app);

    const channel = await CreateChannel();

    // Customer routes
    customer(app, channel);

    // error handling (if you add later)
};
