const { ProductRepository } = require("../database");
const { FormateData } = require("../utils");

// All Business logic will be here
class ProductService {

    constructor() {
        this.repository = new ProductRepository();
    }

    // Create a new product
    async CreateProduct(productInputs) {
        const productResult = await this.repository.CreateProduct(productInputs);
        return FormateData(productResult);
    }

    // Update inventory count (add or subtract units)
    async UpdateInventory(productId, qty, isAddition = false) {
        // Call the atomic repository method
        const result = await this.repository.UpdateStock(productId, qty, isAddition);

        if (result) {
            return FormateData(result);
        }

        // If result is null, it means either the product wasn't found 
        // OR the stock was insufficient (the $gte check failed).
        return FormateData({ error: 'Update failed: Product not found or Insufficient stock' });
    }

    // Get all products with unique categories
    async GetProducts() {
        const products = await this.repository.Products();

        let categories = {};

        // Using forEach since we are mutating categories (map is for transformations)
        products.forEach(({ type }) => {
            categories[type] = type;
        });

        return FormateData({
            products,
            categories: Object.keys(categories)
        });
    }

    // Get single product details
    async GetProductDescription(productId) {
        const product = await this.repository.FindById(productId);
        return FormateData(product);
    }

    // Get products by category
    async GetProductsByCategory(category) {
        const products = await this.repository.FindByCategory(category);
        return FormateData(products);
    }

    // Get selected products by IDs
    async GetSelectedProducts(selectedIds) {
        const products = await this.repository.FindSelectedProducts(selectedIds);
        return FormateData(products);
    }

    // Prepare product payload for events (e.g., order, cart, etc.)
    async GetProductPayload(userId, { productId, qty }, event) {
        const product = await this.repository.FindById(productId);

        if (product) {
            const payload = {
                event: event,
                data: { userId, product, qty }
            };

            return FormateData(payload);
        } else {
            return FormateData({ error: 'No product Available' });
        }
    }

    // Delete product by ID
    async DeleteProduct(productId) {
        const deletedProduct = await this.repository.DeleteProductById(productId);
        return FormateData(deletedProduct);
    }

    // Update product details
    async UpdateProduct(productId, productInputs) {
        const updatedProduct = await this.repository.UpdateProduct(productId, productInputs);
        return FormateData(updatedProduct);
    }
}

module.exports = ProductService;