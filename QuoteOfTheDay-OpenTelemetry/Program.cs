using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.FeatureManagement;
using QuoteOfTheDay.Data;

var builder = WebApplication.CreateBuilder(args);

bool isRunningFromSetupScript = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("RUNNING_EF_MIGRATIONS_SETUP"));
var appConfigurationEndpoint = builder.Configuration["APPCONFIG_ENDPOINT"];
var applicationInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];

if (!isRunningFromSetupScript && !string.IsNullOrEmpty(appConfigurationEndpoint))
{
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options.Connect(new Uri(appConfigurationEndpoint), new DefaultAzureCredential());
        options.UseFeatureFlags();
        options.ConfigureStartupOptions(startupOptions =>
        {
            startupOptions.Timeout = TimeSpan.FromSeconds(30);
        });
    });
}

builder.Services.AddAzureAppConfiguration()
    .AddFeatureManagement()
    .WithTargeting();

var openTelemetry = builder.Services.AddOpenTelemetry();

// Targeting processors must run before exporters to enrich events with TargetingId.
openTelemetry.AddFeatureManagementProcessors();

if (!isRunningFromSetupScript && !string.IsNullOrEmpty(applicationInsightsConnectionString))
{
    openTelemetry.UseAzureMonitor(options =>
    {
        options.ConnectionString = applicationInsightsConnectionString;
        // Keep experiment events even during bursts or under an unsampled parent trace.
        options.TracesPerSecond = null;
        options.SamplingRatio = 1.0F;
        options.EnableTraceBasedLogsSampler = false;
    });
}

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(connectionString));
builder.Services.AddDatabaseDeveloperPageExceptionFilter();

builder.Services.AddDefaultIdentity<IdentityUser>(options => options.SignIn.RequireConfirmedAccount = true)
    .AddEntityFrameworkStores<ApplicationDbContext>();
builder.Services.AddRazorPages();

var app = builder.Build();

if (!isRunningFromSetupScript && string.IsNullOrEmpty(applicationInsightsConnectionString))
{
    app.Logger.LogWarning("APPLICATIONINSIGHTS_CONNECTION_STRING is not configured. Telemetry will not be exported to Azure Monitor.");
}

if (app.Environment.IsDevelopment())
{
    app.UseMigrationsEndPoint();
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseAzureAppConfiguration();
app.UseAuthentication();
app.UseMiddleware<TargetingHttpContextMiddleware>();
app.UseAuthorization();

app.MapRazorPages();
app.Run();
