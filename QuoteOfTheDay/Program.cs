using Azure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using QuoteOfTheDay.Data;
using Microsoft.ApplicationInsights.AspNetCore.Extensions;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.FeatureManagement.Telemetry.ApplicationInsights;
using Microsoft.FeatureManagement;

var builder = WebApplication.CreateBuilder(args);

var appConfigurationEndpoint = builder.Configuration["APPCONFIG_ENDPOINT"];
var applicationInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];

builder.Configuration
    .AddAzureAppConfiguration(o =>
    {
        o.Connect(new Uri(appConfigurationEndpoint), new DefaultAzureCredential());
        o.UseFeatureFlags();
        o.ConfigureStartupOptions(startupOptions => {
            startupOptions.Timeout = TimeSpan.FromSeconds(30);
        });
    });

// Add Application Insights telemetry.
builder.Services.AddApplicationInsightsTelemetry(
    new ApplicationInsightsServiceOptions
    {
        ConnectionString = applicationInsightsConnectionString,
        EnableAdaptiveSampling = false
    })
    .AddSingleton<ITelemetryInitializer, TargetingTelemetryInitializer>();

// Add Azure App Configuration and feature management services to the container.
builder.Services.AddAzureAppConfiguration()
    .AddFeatureManagement()
    .WithTargeting()
    .AddApplicationInsightsTelemetryPublisher();

// Add services to the container.
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(connectionString));
builder.Services.AddDatabaseDeveloperPageExceptionFilter();

builder.Services.AddDefaultIdentity<IdentityUser>(options => options.SignIn.RequireConfirmedAccount = true)
    .AddEntityFrameworkStores<ApplicationDbContext>();
builder.Services.AddRazorPages();

var app = builder.Build();

// Use Azure App Configuration middleware for dynamic configuration refresh.
app.UseAzureAppConfiguration();

// Add TargetingId to HttpContext for telemetry
app.UseMiddleware<TargetingHttpContextMiddleware>();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseMigrationsEndPoint();
}
else
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

app.Run();
