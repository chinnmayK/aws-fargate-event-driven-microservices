const { CustomerRepository } = require("../database");
const {
    FormateData,
    GeneratePassword,
    GenerateSalt,
    GenerateSignature,
    ValidatePassword
} = require('../utils');

// All Business logic will be here
class CustomerService {

    constructor(){
        // Initialize repository
        this.repository = new CustomerRepository();
    }

    // Customer Sign In
    async SignIn(userInputs){

        const { email, password } = userInputs;
        
        // Find customer by email
        const existingCustomer = await this.repository.FindCustomer({ email });

        if(existingCustomer){
            // Validate password using stored hash & salt
            const validPassword = await ValidatePassword(
                password,
                existingCustomer.password,
                existingCustomer.salt
            );

            if(validPassword){
                // Generate JWT token
                const token = await GenerateSignature({
                    email: existingCustomer.email,
                    _id: existingCustomer._id
                });

                return FormateData({ id: existingCustomer._id, token });
            }
        }

        // Invalid credentials
        return FormateData(null);
    }

    // Customer Sign Up
    async SignUp(userInputs){
        
        const { email, password, phone } = userInputs;
        
        // Create salt
        const salt = await GenerateSalt();
        
        // Hash password
        const userPassword = await GeneratePassword(password, salt);
        
        // Create customer record
        const existingCustomer = await this.repository.CreateCustomer({
            email,
            password: userPassword,
            phone,
            salt
        });
        
        // Generate JWT token
        const token = await GenerateSignature({
            email: email,
            _id: existingCustomer._id
        });

        return FormateData({ id: existingCustomer._id, token });
    }

    // Add new address to customer profile
    async AddNewAddress(_id, userInputs){
        
        const { street, postalCode, city, country } = userInputs;
    
        const addressResult = await this.repository.CreateAddress({
            _id,
            street,
            postalCode,
            city,
            country
        });

        return FormateData(addressResult);
    }

    // Get customer profile
    async GetProfile(id){
        const existingCustomer = await this.repository.FindCustomerById({ id });
        return FormateData(existingCustomer);
    }

    // Get shopping details (orders, cart, etc.)
    async GetShopingDetails(id){

        const existingCustomer = await this.repository.FindCustomerById({ id });

        if(existingCustomer){
            // Orders could be fetched from another service if needed
            return FormateData(existingCustomer);
        }

        return FormateData({ msg: 'Error' });
    }

    // Get wishlist items
    async GetWishList(customerId){
        const wishListItems = await this.repository.Wishlist(customerId);
        return FormateData(wishListItems);
    }

    // Add product to wishlist
    async AddToWishlist(customerId, product){
        const wishlistResult = await this.repository.AddWishlistItem(
            customerId,
            product
        );
        return FormateData(wishlistResult);
    }

    // Remove product from wishlist
    async RemoveFromWishlist(customerId, productId){
        const wishlistResult = await this.repository.AddWishlistItem(
            customerId,
            { _id: productId },
            true // removal flag
        );
        return FormateData(wishlistResult);
    }

    // Add / Remove item from cart
    async ManageCart(customerId, product, qty, isRemove){
        const cartResult = await this.repository.AddCartItem(
            customerId,
            product,
            qty,
            isRemove
        );
        return FormateData(cartResult);
    }

    // Add order to customer profile
    async ManageOrder(customerId, order){
        const orderResult = await this.repository.AddOrderToProfile(
            customerId,
            order
        );
        return FormateData(orderResult);
    }

    // Handle events from message broker (RabbitMQ)
    async SubscribeEvents(payload){
 
        console.log('Triggering.... Customer Events');

        // Parse message payload safely
        payload = JSON.parse(payload);

        const { event, data } = payload;
        const { userId, product, order, qty } = data;

        switch(event){
            case 'ADD_TO_WISHLIST':
                await this.AddToWishlist(userId, product);
                break;

            case 'REMOVE_FROM_WISHLIST':
                await this.RemoveFromWishlist(userId, product._id);
                break;

            case 'ADD_TO_CART':
                await this.ManageCart(userId, product, qty, false);
                break;

            case 'REMOVE_FROM_CART':
                await this.ManageCart(userId, product, qty, true);
                break;

            case 'CREATE_ORDER':
                await this.ManageOrder(userId, order);
                break;

            default:
                break;
        }
    }

    // Delete customer profile
    async DeleteProfile(customerId) {
        const result = await this.repository.DeleteCustomerById(customerId);

        // You would publish a 'DELETE_PROFILE' event to RabbitMQ here
        return FormateData(result);
    }
}

module.exports = CustomerService;