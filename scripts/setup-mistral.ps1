Param(
  [Parameter(Mandatory=$true)][string]$Key
)
setx MISTRAL_API_KEY $Key | Out-Null
Write-Host "MISTRAL_API_KEY persisted. Restart your terminal or app."
