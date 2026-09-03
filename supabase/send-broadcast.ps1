# =============================================================================
# send-broadcast.ps1 — يبعت إشعارًا عامًا (broadcast) لكل المستخدمين بشكل يدوي.
# استخدام من المالك فقط (الإشعار محمي بسر مشترك، مش متاح لأي مستخدم).
#
# ملاحظة مهمة: بنستخدم curl.exe مع ملف JSON بترميز UTF-8 لأن Invoke-RestMethod في
# PowerShell 5.1 بيرسل الـ body بترميز ANSI فيبوظ العربي (بيظهر ??). الحل هنا
# بيكتب الـ body في ملف UTF-8 ويبعتو بـ curl --data-binary @file (بيّات بحرفه).
#
# الاستخدام:
#   .\send-broadcast.ps1 -Title "عنوان الإشعار" -Body "التفاصيل" `
#       [-ImageUrl "https://.../x.png"] [-DeepLink home] [-ExternalLink "https://..."]
#
# أمثلة:
#   .\send-broadcast.ps1 -Title "صيانة مجدولة" -Body "التطبيق هيبقى تحت صيانة"
#   .\send-broadcast.ps1 -Title "عرض جديد" -Body "خصم 30%" -ImageUrl "https://.../o.png" -DeepLink home
#   .\send-broadcast.ps1 -Title "تابعنا" -Body "صفحتنا الرسمية" -ExternalLink "https://facebook.com/page"
#
# ملاحظة على الوجهة عند الضغط:
#   - -ExternalLink (رابط يبدأ بـ http:// أو https://) → يفتح في المتصفح بره التطبيق.
#   - -DeepLink home (أو أي قيمة داخلية) → يفتح شاشة جوه التطبيق.
#   - لو اتحدّد الإثنين، الرابط الخارجي هو اللي ياخد الأولوية.
# =============================================================================

param(
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter(Mandatory=$true)][string]$Body,
  [string]$ImageUrl = "",
  [string]$DeepLink = "",
  [string]$ExternalLink = ""
)

$ErrorActionPreference = "Stop"

$secret = $env:MAHWAR_BROADCAST_SECRET
if ([string]::IsNullOrEmpty($secret)) {
  throw "MAHWAR_BROADCAST_SECRET env var is required. Set it to the ORDER_EVENT_SECRET value before sending a broadcast."
}

$FunctionUrl = "https://trgesfzojaoirutkkfcs.supabase.co/functions/v1/send-broadcast-notification"

# التحقق من صحة الرابط الخارجي إن اتحدد
if ($ExternalLink -and -not ($ExternalLink -match "^https?://")) {
  throw "-ExternalLink لازم يبدأ بـ http:// أو https://"
}

# نبني الـ payload كـ Hashtable ونحوله JSON (يحافظ على UTF-8 عند كتابة الملف)
$payload = @{
  title = $Title
  body  = $Body
}
if ($ImageUrl) { $payload.image_url = $ImageUrl }

# الرابط الخارجي له الأولوية على الـ deep link الداخلي.
# الاتنين بيتحفظوا في نفس الحقل deep_link (إما "home" أو رابط http(s) خارجي)
# وبالتطبيق يفرّق عند الضغط: خارجي → متصفح، داخلي → شاشة جوه التطبيق.
if ($ExternalLink) {
  $payload.deep_link = $ExternalLink
} elseif ($DeepLink) {
  $payload.deep_link = $DeepLink
}

$json = $payload | ConvertTo-Json -Compress

# نكتبه في ملف بترميز UTF-8 (بدون BOM عشان curl يقراه صح)
$tmp = Join-Path $env:TEMP "mahwar_broadcast_$([guid]::NewGuid().ToString('N')).json"
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))

try {
  $resp = & curl.exe -s -X POST $FunctionUrl `
    -H "x-order-event-secret: $secret" `
    -H "Content-Type: application/json" `
    --data-binary "@$tmp"
  Write-Output "RESPONSE: $resp"
} finally {
  Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
}
