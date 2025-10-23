# Test with multiple concurrent requests to maximize GPU usage
Write-Host "Starting concurrent GPU load test..." -ForegroundColor Green
Write-Host "This will send 4 parallel requests to maximize GPU usage" -ForegroundColor Yellow
Write-Host "Open another terminal and run: nvidia-smi -l 1" -ForegroundColor Cyan
Write-Host ""

$numRequests = 4
$jobs = @()

$prompts = @(
    "Write a detailed 2000-word essay about artificial intelligence and its impact on society",
    "Explain quantum computing in 2000 words with detailed examples",
    "Describe the future of renewable energy in 2000 words",
    "Write a comprehensive guide to machine learning in 2000 words"
)

1..$numRequests | ForEach-Object {
    $promptIndex = ($_ - 1) % $prompts.Length
    
    $jobs += Start-Job -ScriptBlock {
        param($url, $model, $prompt)
        
        $body = @{
            model = $model
            prompt = $prompt
            stream = $false
            options = @{
                num_ctx = 8192
                num_predict = 2000
                temperature = 0.7
            }
        } | ConvertTo-Json

        $startTime = Get-Date
        $response = Invoke-RestMethod -Uri $url `
            -Method Post `
            -ContentType "application/json" `
            -Body $body
        $endTime = Get-Date
        
        @{
            Duration = ($endTime - $startTime).TotalSeconds
            WordCount = ($response.response -split '\s+').Count
            Response = $response.response.Substring(0, [Math]::Min(200, $response.response.Length))
        }
    } -ArgumentList "http://localhost:11434/api/generate", "qwen2.5:7b-instruct", $prompts[$promptIndex]
                                                            qwen2.5:7b-instruct
    Write-Host "Started request $_ with prompt: $($prompts[$promptIndex].Substring(0,50))..." -ForegroundColor Green
    Start-Sleep -Milliseconds 500
}

Write-Host "`nAll requests started! Waiting for completion..." -ForegroundColor Yellow
Write-Host "Check GPU usage now - it should be 60-80%+" -ForegroundColor Cyan

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

Write-Host "`n=== Results ===" -ForegroundColor Green
$results | ForEach-Object {
    Write-Host "Duration: $($_.Duration) seconds | Words: $($_.WordCount)" -ForegroundColor Cyan
    Write-Host "Preview: $($_.Response)..." -ForegroundColor Gray
    Write-Host ""
}

Write-Host "All requests completed!" -ForegroundColor Green