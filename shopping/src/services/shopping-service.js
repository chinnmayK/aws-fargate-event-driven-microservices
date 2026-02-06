const { ShoppingRepository } = require("../database");
const { FormateData } = require("../utils");

// All Business logic will be here
class ShoppingService {

    constructor(){
        this.repository = new ShoppingRepository();
    }

    async GetCart({ _id }){
        const cartItems = await this.repository.Cart(_id);
        return FormateData(cartItems);
    }

    async AddToCart(customerId, product_id) {
        try {
            // Assumes repository supports adding a single item with default qty = 1
            const cartResult = await this.repository.AddCartItem(customerId, product_id);
            return { data: cartResult };
        } catch (err) {
            console.log(err);
            return { data: { error: "Could not add to cart" } };
        }
    }

    async PlaceOrder(userInput){
        const { _id, txnNumber } = userInput; // Ensure txnNumber is passed from controller

        try {
            // 1. Create the Order
            const orderResult = await this.repository.CreateNewOrder(_id, txnNumber);
            
            if(orderResult){
                // 2. Clear the Cart 
                await this.repository.DeleteCart(_id); 

                // 3. Prepare Payload for RabbitMQ
                const payload = await this.GetOrderPayload(_id, orderResult, 'CREATE_ORDER');
                
                // Return both result and payload so the controller can Publish
                return FormateData({ orderResult, payload });
            }

            return FormateData({ error: 'Order Creation Failed' });
        } catch (err) {
            console.log(err);
            throw new Error("Data Not found");
        }
    }

    async GetOrders(customerId){
        const orders = await this.repository.Orders(customerId);
        return FormateData(orders);
    }

    async GetOrderDetails(orderId) {
        const order = await this.repository.FindOrderById(orderId); // Specific ID search
        return FormateData(order);
    }

    async ManageCart(customerId, item, qty, isRemove){
        // Used for ADD / REMOVE cart events
        const cartResult = await this.repository.AddCartItem(
            customerId,
            item,
            qty,
            isRemove
        );
        return FormateData(cartResult);
    }

    async SubscribeEvents(payload){
        try {
            payload = JSON.parse(payload);
            const { event, data } = payload;
            const { userId, product, qty } = data;
            
            switch(event){
                case 'ADD_TO_CART':
                    await this.ManageCart(userId, product, qty, false);
                    break;

                case 'REMOVE_FROM_CART':
                    await this.ManageCart(userId, product, qty, true);
                    break;

                case 'DELETE_PROFILE':
                    // TODO: Add logic to wipe cart and orders if user deletes account
                    break;

                default:
                    break;
            }
        } catch (err) {
            console.error("Error in Shopping Subscription:", err);
        }
    }

    async GetOrderPayload(userId, order, event){
        if(order){
            const payload = { 
                event: event,
                data: { userId, order }
            };
            return payload;
        } else {
            return FormateData({ error: 'No Order Available' });
        }
    }

    async RemoveFromCart(customerId, productId) {
        const result = await this.repository.RemoveCartItem(customerId, productId);
        return FormateData(result);
    }

    async UpdateOrderStatus(orderId, status) {
        const result = await this.repository.UpdateOrder(orderId, status);
        return FormateData(result);
    }
}

module.exports = ShoppingService;