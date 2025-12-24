var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello from Azure Deploy POC!");
app.MapGet("/health", () => "Healthy");

app.Run();
