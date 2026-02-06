const mongoose = require('mongoose');
const { OrderModel, CartModel } = require('../models');
const { v4: uuidv4 } = require('uuid');

//Dealing with data base operations
class ShoppingRepository {

    async Orders(customerId){

        const orders = await OrderModel.find({customerId });
        
        return orders;

    }

    async Cart(customerId){

        const cartItems = await CartModel.find({ customerId: customerId });


        if(cartItems){
            return cartItems;
        }

        throw new Error('Data Not found!');
    }

    async DeleteCart(customerId){
        return await CartModel.deleteOne({ customerId });
    }

    async AddCartItem(customerId,item,qty,isRemove){
 
            // return await CartModel.deleteMany();
 
            const cart = await CartModel.findOne({ customerId: customerId })

            const { _id } = item;

            if(cart){
                
                let isExist = false;

                let cartItems = cart.items;


                if(cartItems.length > 0){

                    cartItems.map(item => {
                                                
                        if(item.product._id.toString() === _id.toString()){
                            if(isRemove){
                                cartItems.splice(cartItems.indexOf(item), 1);
                             }else{
                               item.unit = qty;
                            }
                             isExist = true;
                        }
                    });
                } 
                
                if(!isExist && !isRemove){
                    cartItems.push({product: { ...item}, unit: qty });
                }

                cart.items = cartItems;

                return await cart.save()
 
            }else{

               return await CartModel.create({
                    customerId,
                    items:[{product: { ...item}, unit: qty }]
                })
            }

        
    }

    async CreateNewOrder(customerId, txnId) {
        const cart = await CartModel.findOne({ customerId });
        if (cart) {
            let amount = 0;
            cart.items.map(item => {
                // Defensive check to ensure we don't get NaN
                const price = parseFloat(item.product.price);
                const unit = parseInt(item.unit);
                if(!isNaN(price) && !isNaN(unit)){
                    amount += price * unit;
                }
        });

            const orderId = uuidv4(); 
            const order = new OrderModel({
                orderId,
                customerId,
                amount, // This was NaN
                txnId,
                status: 'received',
                items: cart.items
            });

            const orderResult = await order.save();
            return orderResult;
        }
        return null;
    }

}

module.exports = ShoppingRepository;
