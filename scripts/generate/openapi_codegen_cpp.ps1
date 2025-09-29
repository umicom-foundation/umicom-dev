$Schema = "third_party/api-schemas/mistral/openapi.yaml"
$Out = "clients/mistral-cpp"
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
openapi-generator generate -i $Schema -g cpp-httplib -o $Out
Write-Host "Generated C++ client in $Out"
