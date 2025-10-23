# Test GPU load with single request
Write-Host "Testing Ollama GPU utilization..." -ForegroundColor Green
Write-Host "Monitor GPU usage in another terminal with: nvidia-smi -l 1" -ForegroundColor Yellow

$body = @{
    model = "qwen2.5:7b-instruct"
    prompt = "Write a comprehensive 3000-word essay about artificial intelligence, machine learning, deep learning, and their applications in modern technology. Include detailed examples, explanations, and future predictions."
    stream = $false
    options = @{
        num_ctx = 8192
        num_predict = 3000
        temperature = 0.7
    }
} | ConvertTo-Json

Write-Host "`nSending request..." -ForegroundColor Cyan
$response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

Write-Host "`nResponse received!" -ForegroundColor Green
Write-Host $response.response