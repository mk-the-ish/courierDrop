param(
  [string]$BackendUrl = "http://localhost:8080",
  [string]$Token = "",
  [int]$Days = 30
)

if ($Token -eq "") {
  Write-Error "Token is required."
  exit 1
}

$uri = "$BackendUrl/admin/handshake/cleanup"
$body = @{ days = $Days } | ConvertTo-Json

$response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
  Authorization = "Bearer $Token"
  "Content-Type" = "application/json"
} -Body $body

Write-Output $response
