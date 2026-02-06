const mongoose = require('mongoose');
const { ProductModel } = require("../models");

//Dealing with data base operations
class ProductRepository {


    async CreateProduct({ name, desc, type, unit,price, available, suplier, banner }){

        const product = new ProductModel({
            name, desc, type, unit,price, available, suplier, banner
        })

    //    return await ProductModel.findByIdAndDelete('607286419f4a1007c1fa7f40');

        const productResult = await product.save();
        return productResult;
    }


     async Products(){
        return await ProductModel.find();
    }
   
    async FindById(id){
        
       return await ProductModel.findById(id);

    }

    async FindByCategory(category){

        const products = await ProductModel.find({ type: category});

        return products;
    }

    async FindSelectedProducts(selectedIds){
        const products = await ProductModel.find().where('_id').in(selectedIds.map(_id => _id)).exec();
        return products;
    }

    // product-repository.js

    async UpdateStock(productId, qty, isAddition) {
        // If it's an addition, qty is positive; if subtraction, qty is negative
        const adjustQty = isAddition ? qty : -qty;

        // The filter { unit: { $gte: qty } } ensures we only update 
        // IF the current stock is greater than or equal to what we want to take.
        const query = {
            _id: productId
        };

        if (!isAddition) {
            query.unit = { $gte: qty }; // Only subtract if stock is sufficient
        }

        const result = await ProductModel.findOneAndUpdate(
            query,
            { $inc: { unit: adjustQty } },
            { new: true } // returns the updated document
        );

        return result; 
    }
    
}

module.exports = ProductRepository;
