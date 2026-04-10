param(
  [Parameter(Mandatory = $true)]
  [string]$FilePath,
  [string]$BackendUrl = "http://localhost:8080",
  [string]$Token = "",
  [string]$ParcelId = ""
)

if (-not (Test-Path $FilePath)) {
  Write-Error "File not found: $FilePath"
  exit 1
}

$url = "$BackendUrl/handshake/upload"
$authHeader = ""
if ($Token -ne "") {
  $authHeader = "Authorization: Bearer $Token"
}

$args = @("-s", "-X", "POST", $url, "-F", "photo=@$FilePath")
if ($ParcelId -ne "") {
  $args += "-F"
  $args += "parcelId=$ParcelId"
}
if ($authHeader -ne "") {
  $args += "-H"
  $args += $authHeader
}

Write-Host "Uploading $FilePath to $url"
$response = & curl.exe @args
Write-Host $response
