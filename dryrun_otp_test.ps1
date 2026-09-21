# =============================================================================
# dryrun_otp_test.ps1 - dry-run check for the Send SMS hook (Mahwar).
#
# Runs while SMS_DRY_RUN=true: the send-sms-hook function returns 200 and
# records a 'dryrun' row in sms_send_logs WITHOUT calling ZADX. No SMS is sent
# and the phone change stays unapplied.
#
# This script does NOT contain any credentials. It asks you to type them when
# you run it. The password is hidden while typing and the token is never printed.
# =============================================================================

$ErrorActionPreference = 'Stop'

$ProjectRef = 'trgesfzojaoirutkkfcs'
$BaseUrl    = "https://$ProjectRef.supabase.co"

Write-Host ""
Write-Host "Mahwar - SMS hook dry-run test"
Write-Host "No SMS will be sent (SMS_DRY_RUN=true)."
Write-Host ""

# -----------------------------------------------------------------------------
# Ask for the values at runtime
# -----------------------------------------------------------------------------
$AnonKey   = (Read-Host "Anon/publishable key (NOT the service_role or secret key)").Trim()
$TestEmail = (Read-Host "Test account email").Trim()
$SecurePwd = Read-Host "Test account password (hidden while typing)" -AsSecureString
$TestPhone = (Read-Host "Phone to attach, format +2010XXXXXXXX (13 characters)").Trim()

$TestPassword = [System.Net.NetworkCredential]::new('', $SecurePwd).Password

if ($TestPhone -notmatch '^\+201[0125][0-9]{8}$') {
    Write-Host ""
    Write-Host "Phone format is wrong. It must look like +201012345678 (no spaces, no leading 0 after +20)."
    return
}
if ($AnonKey.Length -lt 20) {
    Write-Host ""
    Write-Host "The anon key looks too short. Copy the full key from Project Settings > API Keys."
    return
}

$AuthBase = @{ apikey = $AnonKey }

function Invoke-Json {
    param(
        [string]$Uri,
        [string]$Method = 'Post',
        [hashtable]$Headers,
        [object]$Body
    )
    try {
        $res = Invoke-RestMethod `
            -Uri $Uri -Method $Method -Headers $Headers `
            -ContentType 'application/json; charset=utf-8' `
            -Body ($Body | ConvertTo-Json)
        Write-Host "Status: 200 (OK)"
        return $res
    }
    catch {
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Host ("Status: {0}" -f $code)
        if ($_.ErrorDetails.Message) { Write-Host ("Body:   {0}" -f $_.ErrorDetails.Message) }
        throw
    }
}

try {
    # -------------------------------------------------------------------------
    # Step 1: log in as an existing test user. The token stays in memory only.
    # -------------------------------------------------------------------------
    Write-Host ""
    Write-Host "== Step 1: login =="
    $login = Invoke-Json `
        -Uri "$BaseUrl/auth/v1/token?grant_type=password" `
        -Headers $AuthBase `
        -Body @{ email = $TestEmail; password = $TestPassword }

    $accessToken = [string]$login.access_token
    if (-not $accessToken) { throw "Login succeeded but no access_token was returned." }

    Write-Host ("Body:   user_id={0} (token hidden)" -f $login.user.id)

    # -------------------------------------------------------------------------
    # Step 2: phone change -> Supabase generates an OTP -> Send SMS hook fires
    # -> dry-run returns 200 without delivery. No password in this request.
    # -------------------------------------------------------------------------
    Write-Host ""
    Write-Host "== Step 2: phone change (expect a dryrun row) =="
    $headers = $AuthBase.Clone()
    $headers['Authorization'] = "Bearer $accessToken"

    $updated = Invoke-Json `
        -Uri "$BaseUrl/auth/v1/user" `
        -Method 'Put' `
        -Headers $headers `
        -Body @{ phone = $TestPhone }

    Write-Host ("Body:   id={0} phone_confirmed_at={1} (empty = not verified, as expected)" -f `
        $updated.id, $updated.phone_confirmed_at)

    Write-Host ""
    Write-Host "DONE. Now run the sms_send_logs query in the Supabase SQL editor and look for result = 'dryrun'."
}
catch {
    Write-Host ""
    Write-Host ("FAILED: {0}" -f $_.Exception.Message)
    Write-Host "No SMS was sent - with SMS_DRY_RUN=true the hook never calls ZADX."
}
finally {
    $TestPassword = $null
    $accessToken = $null
}