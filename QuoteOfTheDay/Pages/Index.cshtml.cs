using Microsoft.ApplicationInsights;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.FeatureManagement;

namespace QuoteOfTheDay.Pages;

public class Quote
{
    public string Message { get; set; }

    public string Author { get; set; }
}

public class IndexModel(
    ILogger<IndexModel> logger,
    IVariantFeatureManagerSnapshot featureManager,
    TelemetryClient telemetryClient) : PageModel
{
    private readonly ILogger _logger = logger;
    private readonly IVariantFeatureManagerSnapshot _featureManager = featureManager;
    private readonly TelemetryClient _telemetryClient = telemetryClient;
    private const string GreetingFeatureFlag = "Greeting";

    private readonly Quote[] _quotes = [
        new Quote()
        {
            Message = "You cannot change what you are, only what you do.",
            Author = "Philip Pullman"
        }];

    public Quote? Quote { get; set; }

    public string Greeting { get; set; }

    public async void OnGet()
    {
        Quote = _quotes[new Random().Next(_quotes.Length)];

        Variant variant = await _featureManager.GetVariantAsync(GreetingFeatureFlag, HttpContext.RequestAborted);

        if (variant != null)
        {
            Greeting = variant.Configuration?.Get<string>() ?? "";
        }
        else
        {
            _logger.LogWarning($"Greeting variant not found. Please define a variant feature flag in Azure App Configuration named '{GreetingFeatureFlag}'.");
        }
    }

    public IActionResult OnPostHeartQuoteAsync()
    {
        string? userId = User.Identity?.Name;

        if (!string.IsNullOrEmpty(userId))
        {
            // Send telemetry to Application Insights
            _telemetryClient.TrackEvent("Like");

            return new JsonResult(new { success = true });
        }
        else
        {
            return new JsonResult(new { success = false, error = "User not authenticated" });
        }
    }
}