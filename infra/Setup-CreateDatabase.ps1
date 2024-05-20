$databasePath = "./QuoteOfTheDay\*.db"
$databaseExists = Test-Path -Path $databasePath

if ($databaseExists) {
    Write-Host "The database file already exists."

    exit 0
}

Write-Host "Creating database file."

Set-Location -Path "./QuoteOfTheDay"

$dotnetSDK = dotnet --version
if ($dotnetSDK -eq $null) {
    winget install Microsoft.DotNet.SDK.8
} else {
    Write-Host "The .NET SDK is already installed."
}

dotnet tool install --global dotnet-ef
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet ef migrations add InitialCreate
dotnet ef database update

Write-Host "Created the database file."

Set-Location -Path ".."