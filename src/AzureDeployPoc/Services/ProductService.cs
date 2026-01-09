using AzureDeployPoc.Models;

namespace AzureDeployPoc.Services;

public class ProductService : IProductService
{
    private readonly List<Product> _products = new()
    {
        new Product { Id = 1, Name = "Laptop", Price = 999.99m, Category = "Electronics", InStock = true },
        new Product { Id = 2, Name = "Mouse", Price = 29.99m, Category = "Electronics", InStock = true },
        new Product { Id = 3, Name = "Keyboard", Price = 79.99m, Category = "Electronics", InStock = false }
    };

    public IEnumerable<Product> GetAll() => _products;

    public Product? GetById(int id) => _products.FirstOrDefault(p => p.Id == id);

    public Product Create(Product product)
    {
        product.Id = _products.Max(p => p.Id) + 1;
        _products.Add(product);
        return product;
    }

    public bool Update(int id, Product product)
    {
        var existing = GetById(id);
        if (existing == null) return false;

        existing.Name = product.Name;
        existing.Price = product.Price;
        existing.Category = product.Category;
        existing.InStock = product.InStock;
        return true;
    }

    public bool Delete(int id)
    {
        var product = GetById(id);
        if (product == null) return false;
        return _products.Remove(product);
    }
}
