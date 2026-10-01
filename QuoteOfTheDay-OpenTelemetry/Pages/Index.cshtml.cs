using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.FeatureManagement;

namespace QuoteOfTheDay.Pages;

public class Quote
{
    public string Message { get; set; } = string.Empty;

    public string Author { get; set; } = string.Empty;
}

public class IndexModel(
    ILogger<IndexModel> logger,
    IVariantFeatureManagerSnapshot featureManager) : PageModel
{
    private readonly ILogger _logger = logger;
    private readonly IVariantFeatureManagerSnapshot _featureManager = featureManager;
    private const string GreetingFeatureFlag = "Greeting";

    private readonly Quote[] _quotes = [
        new Quote()
        {
            Message = "You cannot change what you are, only what you do.",
            Author = "Philip Pullman"
        }];

    public Quote? Quote { get; set; }

    public string Greeting { get; set; } = string.Empty;

    public async Task OnGetAsync()
    {
        Quote = _quotes[new Random().Next(_quotes.Length)];

        Variant? variant = await _featureManager.GetVariantAsync(GreetingFeatureFlag, HttpContext.RequestAborted);

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
            // Azure Monitor maps this OpenTelemetry log attribute to a custom event.
            _logger.LogInformation("{microsoft.custom_event.name}", "Like");

            return new JsonResult(new { success = true });
        }
        else
        {
            return new JsonResult(new { success = false, error = "User not authenticated" });
        }
    }
}