const mongoose = require('mongoose');
const { CustomerModel, AddressModel } = require('../models');

class CustomerRepository {

    async CreateCustomer({ email, password, phone, salt }) {
        const customer = new CustomerModel({
            email,
            password,
            salt,
            phone,
            address: []
        });

        const customerResult = await customer.save();
        return customerResult;
    }

    async CreateAddress({ _id, street, postalCode, city, country }) {
        const profile = await CustomerModel.findById(_id);

        if (profile) {
            const newAddress = new AddressModel({
                street,
                postalCode,
                city,
                country
            });

            await newAddress.save();
            profile.address.push(newAddress);
            return await profile.save();
        }

        throw new Error('Customer not found while creating address');
    }

    async FindCustomer({ email }) {
        return await CustomerModel.findOne({ email: email });
    }

    async FindCustomerById({ id }) {
        // Safety: Ensure id is provided to prevent findById(null)
        if (!id) return null;
        return await CustomerModel.findById(id).populate('address');
    }

    async Wishlist(customerId) {
        const profile = await CustomerModel.findById(customerId).populate('wishlist');
        return profile ? profile.wishlist : [];
    }

    async AddWishlistItem(customerId, product, isRemove = false) {
        // product should contain {_id, name, desc, price, available, banner}
        const profile = await CustomerModel.findById(customerId).populate('wishlist');

        if (profile) {
            let wishlist = profile.wishlist;

            if (wishlist.length > 0) {
                let isExist = false;
                
                // Use a standard loop or filter for better readability and to avoid 'undefined' crashes
                wishlist.map((item) => {
                    if (item && item._id && product && product._id && item._id.toString() === product._id.toString()) {
                        const index = wishlist.indexOf(item);
                        wishlist.splice(index, 1);
                        isExist = true;
                    }
                });

                if (!isExist && !isRemove) {
                    wishlist.push(product);
                }
            } else if (!isRemove) {
                wishlist.push(product);
            }

            profile.wishlist = wishlist;
            const profileResult = await profile.save();
            return profileResult.wishlist;
        }

        throw new Error('Unable to update wishlist');
    }

    async AddCartItem(customerId, product, qty, isRemove) {
        const profile = await CustomerModel.findById(customerId).populate('cart');

        if (profile) {
            const cartItem = {
                product: { 
                    _id: product._id, 
                    name: product.name, 
                    price: product.price, 
                    banner: product.banner 
                },
                unit: qty,
            };

            let cartItems = profile.cart;

            if (cartItems.length > 0) {
                let isExist = false;
                cartItems.map((item) => {
                    if (item.product._id.toString() === product._id.toString()) {
                        if (isRemove) {
                            cartItems.splice(cartItems.indexOf(item), 1);
                        } else {
                            item.unit = qty;
                        }
                        isExist = true;
                    }
                });

                if (!isExist && !isRemove) {
                    cartItems.push(cartItem);
                }
            } else if (!isRemove) {
                cartItems.push(cartItem);
            }

            profile.cart = cartItems;
            return await profile.save();
        }

        throw new Error('Unable to add to cart!');
    }

    async AddOrderToProfile(customerId, order) {
        const profile = await CustomerModel.findById(customerId);

        if (profile) {
            if (!profile.orders) {
                profile.orders = [];
            }
            profile.orders.push(order);

            // Logic: Once order is placed, empty the customer's cart in the Customer DB
            profile.cart = [];

            return await profile.save();
        }

        throw new Error('Unable to add to order!');
    }
    
    // Missing Function: Delete Customer
    async DeleteCustomerById(id) {
        return await CustomerModel.findByIdAndDelete(id);
    }
}

module.exports = CustomerRepository;