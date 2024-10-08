using Microsoft.ApplicationInsights;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.FeatureManagement;
using Microsoft.FeatureManagement.FeatureFilters;

namespace QuoteOfTheDay.Pages;

public class SimulateModel : PageModel
{
    private readonly IVariantFeatureManager _featureManager;
    private readonly TelemetryClient _telemetryClient;

    public SimulateModel(IVariantFeatureManager featureManager, TelemetryClient telemetryClient)
    {
        _featureManager = featureManager;
        _telemetryClient = telemetryClient;
    }

    public async void OnGet()
    {
        if (HttpContext.Request.Query?["simulate"].Count > 0) {
            await SimulateUser();
        }
    }

    public async Task SimulateUser() {
        string randomUserId = Guid.NewGuid().ToString();

        var activityFeature = HttpContext.Features.Get<IHttpActivityFeature>();
        activityFeature.Activity.SetBaggage("Microsoft.FeatureManagement.TargetingId", randomUserId);

        Variant variant = await _featureManager.GetVariantAsync("Greeting", new TargetingContext() { UserId= randomUserId });

        // 50% chance to like for None variant
        if (variant.Name == "None")
        {
            if (Random.Shared.Next(0, 100) < 50)
            {
                _telemetryClient.TrackEvent("Like");
            }
        }

        // 80% chance to like for Simple variant
        if (variant.Name == "Simple")
        {
            if (Random.Shared.Next(0, 100) < 80)
            {
                _telemetryClient.TrackEvent("Like");
            }
        }

        // 70% chance to like for Long variant
        if (variant.Name == "Long")
        {
            if (Random.Shared.Next(0, 100) < 70)
            {
                _telemetryClient.TrackEvent("Like");
            }
        }
    }
}

