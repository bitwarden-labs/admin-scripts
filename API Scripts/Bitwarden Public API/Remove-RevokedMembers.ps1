<#
.SYNOPSIS
    Bulk-removes revoked members from a Bitwarden organization using the Public API,
    driven by a CSV file of email addresses.

.DESCRIPTION
    Authenticates to the Bitwarden Public API with an Organization API Key, fetches all
    organization members, then removes every member whose email appears in the supplied
    CSV file AND whose current status is Revoked (-1).

    IMPORTANT - what "remove" means here:
        DELETE /public/members/{id} permanently removes the member from the ORGANIZATION.
        This cannot be undone. The user's Bitwarden account itself is NOT deleted - they
        keep their personal vault. For organizations with a claimed domain, full account
        deletion is a separate, per-user action in the Admin Console.

    Use this when the Admin Console will not let you bulk-delete revoked users - for
    example, when the members are claimed-domain managed accounts and the multi-select
    menu only offers "Restore access".

    A -WhatIf switch performs a dry run that lists what WOULD be removed without making
    any DELETE calls. Only members whose CURRENT status is Revoked are ever removed, so a
    stray non-revoked address in the CSV is skipped rather than deleted.

.PARAMETER ClientId
    Organization API Key client_id (prefix "organization."). From the Admin Console:
    Settings > Organization Info > View API Key.

.PARAMETER ClientSecret
    Organization API Key client_secret. Keep this confidential.

.PARAMETER CsvPath
    Path to a CSV file with a header row. The default email column is "email"; change it
    with -EmailColumn. Extra columns are ignored.

.PARAMETER EmailColumn
    Name of the CSV column that holds email addresses. Default: "email".

.PARAMETER IdentityUrl
    OAuth2 token endpoint. Default is US Cloud. For EU Cloud use
    https://identity.bitwarden.eu/connect/token; for self-hosted use
    https://YOUR_DOMAIN/identity/connect/token.

.PARAMETER ApiBaseUrl
    Public API base URL. Default is US Cloud. For EU Cloud use https://api.bitwarden.eu;
    for self-hosted use https://YOUR_DOMAIN/api.

.EXAMPLE
    # Dry run first - shows what would be removed without touching anything:
    .\Remove-RevokedMembers.ps1 -ClientId "organization.xxxx" -ClientSecret "SECRET" -CsvPath ".\revoked.csv" -WhatIf

.EXAMPLE
    # Live run:
    .\Remove-RevokedMembers.ps1 -ClientId "organization.xxxx" -ClientSecret "SECRET" -CsvPath ".\revoked.csv"

.NOTES
    Requires: PowerShell 7+, a Bitwarden Enterprise plan, and an Organization API Key.
    Always test on a small batch with -WhatIf before running against your full list.
    Docs: https://bitwarden.com/help/public-api/
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$ClientSecret,
    [Parameter(Mandatory)][string]$CsvPath,
    [string]$EmailColumn = 'email',
    [string]$IdentityUrl = 'https://identity.bitwarden.com/connect/token',
    [string]$ApiBaseUrl  = 'https://api.bitwarden.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Member status enum (OrganizationUserStatusType in bitwarden/server):
#   Revoked = -1, Invited = 0, Accepted = 1, Confirmed = 2
$StatusRevoked = -1

# --- Validate the CSV -------------------------------------------------------
if (-not (Test-Path -LiteralPath $CsvPath)) { Write-Error "CSV not found: $CsvPath"; exit 1 }
$csvRows = Import-Csv -Path $CsvPath
if ($csvRows.Count -eq 0) { Write-Warning 'CSV is empty. Nothing to do.'; exit 0 }
if ($csvRows[0].PSObject.Properties.Name -notcontains $EmailColumn) {
    Write-Error ("CSV has no '{0}' column. Columns found: {1}. Use -EmailColumn to override." -f `
        $EmailColumn, ($csvRows[0].PSObject.Properties.Name -join ', ')); exit 1
}
$csvEmails = $csvRows.$EmailColumn | Where-Object { $_ -and $_.Trim() } |
             ForEach-Object { $_.Trim().ToLowerInvariant() } | Sort-Object -Unique
Write-Host "CSV loaded: $($csvEmails.Count) unique email(s) to process." -ForegroundColor Cyan

# --- Authenticate -----------------------------------------------------------
function Get-BearerToken {
    param([string]$Endpoint, [string]$Id, [string]$Secret)
    $body = @{ grant_type = 'client_credentials'; scope = 'api.organization'; client_id = $Id; client_secret = $Secret }
    $r = Invoke-RestMethod -Method Post -Uri $Endpoint -Body $body -ContentType 'application/x-www-form-urlencoded'
    if (-not $r.access_token) { Write-Error 'No access_token returned by identity service.'; exit 1 }
    return $r.access_token
}
$token   = Get-BearerToken -Endpoint $IdentityUrl -Id $ClientId -Secret $ClientSecret
$headers = @{ Authorization = "Bearer $token" }

# Re-authenticate transparently if the token expires mid-run (HTTP 401).
function Invoke-ApiWithRetry {
    param([string]$Method, [string]$Uri, [hashtable]$Headers)
    try { return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers }
    catch {
        if ($_.Exception.Response?.StatusCode.value__ -eq 401) {
            Write-Host 'Token expired - re-authenticating...' -ForegroundColor Yellow
            $script:token   = Get-BearerToken -Endpoint $IdentityUrl -Id $ClientId -Secret $ClientSecret
            $script:headers = @{ Authorization = "Bearer $script:token" }
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $script:headers
        }
        throw
    }
}

# --- Fetch members and build email -> member lookup -------------------------
Write-Host 'Fetching organization members...'
$members = (Invoke-ApiWithRetry -Method Get -Uri "$ApiBaseUrl/public/members" -Headers $headers).data
Write-Host "Members returned by API: $($members.Count)"
$byEmail = @{}
foreach ($m in $members) { $byEmail[$m.email.Trim().ToLowerInvariant()] = $m }

# --- Process ----------------------------------------------------------------
$removed = 0; $skipped = 0; $missing = 0; $errors = 0
foreach ($email in $csvEmails) {
    if (-not $byEmail.ContainsKey($email)) {
        Write-Warning "SKIP  not found in org: $email"; $missing++; continue
    }
    $m = $byEmail[$email]
    if ([int]$m.status -ne $StatusRevoked) {
        Write-Host "SKIP  $email - current status is $($m.status), not Revoked. Not touching." -ForegroundColor Yellow
        $skipped++; continue
    }
    if ($PSCmdlet.ShouldProcess($email, "DELETE /public/members/$($m.id)")) {
        try {
            Invoke-ApiWithRetry -Method Delete -Uri "$ApiBaseUrl/public/members/$($m.id)" -Headers $headers | Out-Null
            Write-Host "REMOVED  $email (member id: $($m.id))" -ForegroundColor Green; $removed++
        }
        catch {
            Write-Warning "ERROR  $email (member id: $($m.id)) - $_"; $errors++
        }
    }
}

# --- Summary ----------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Removed (from org)    : $removed"
Write-Host "Skipped (not revoked) : $skipped"
Write-Host "Not found in org      : $missing"
Write-Host "Errors                : $errors"
Write-Host "CSV emails total      : $($csvEmails.Count)"
Write-Host "========================================" -ForegroundColor Cyan
if ($WhatIfPreference) { Write-Host 'Dry run only. Re-run without -WhatIf to execute removals.' -ForegroundColor Yellow }
