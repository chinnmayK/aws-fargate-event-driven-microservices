const ShoppingService = require("../services/shopping-service");
const { PublishCustomerEvent, SubscribeMessage } = require("../utils");
const  UserAuth = require('./middlewares/auth');
const { CUSTOMER_SERVICE } = require('../config');
const { PublishMessage } = require('../utils')

module.exports = (app, channel) => {
    
    const service = new ShoppingService();

    SubscribeMessage(channel, service)

    app.post('/order', UserAuth, async (req, res, next) => {
        const { _id } = req.user;
        const { txnId } = req.body;

        // 1. Call the service (which now has DeleteCart fixed)
        const { data } = await service.PlaceOrder({ _id, txnId });

        // 2. Prepare the message for RabbitMQ
        // We use data.orderResult because that's what the service returns
        const payload = await service.GetOrderPayload(_id, data.orderResult, 'CREATE_ORDER');
        
        // 3. UNCOMMENT THIS to actually send the data to RabbitMQ
        // Make sure CUSTOMER_SERVICE is imported from config (it is!)
        PublishMessage(channel, CUSTOMER_SERVICE, JSON.stringify(payload));
        
        return res.status(200).json(data.orderResult);
    });

    app.get('/orders',UserAuth, async (req,res,next) => {

        const { _id } = req.user;

        const { data } = await service.GetOrders(_id);
        
        res.status(200).json(data);

    });

    app.put('/cart',UserAuth, async (req,res,next) => {

        const { _id } = req.user;

        const { data } = await service.AddToCart(_id, req.body._id);
        
        res.status(200).json(data);

    });

    app.delete('/cart/:id',UserAuth, async (req,res,next) => {

        const { _id } = req.user;


        const { data } = await service.AddToCart(_id, req.body._id);
        
        res.status(200).json(data);

    });
    
    app.get('/cart', UserAuth, async (req,res,next) => {

        const { _id } = req.user;
        
        const { data } = await service.GetCart({ _id });

        return res.status(200).json(data);
    });

    app.get('/whoami', (req,res,next) => {
        return res.status(200).json({msg: '/shoping : I am Shopping Service'})
    })
 
}
