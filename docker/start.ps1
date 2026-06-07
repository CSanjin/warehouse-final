# Docker 精简集群一键启动（Windows PowerShell）
$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot -Parent
Set-Location $RootDir

if (-not (Test-Path ".env")) {
    Copy-Item "docker\.env.example" ".env"
    Write-Host "已创建 .env，默认密码 warehouse123" -ForegroundColor Yellow
}

Write-Host "启动精简集群（2 容器：Web + MySQL）..." -ForegroundColor Cyan
docker compose up -d --build

Write-Host ""
Write-Host "Web 访问: http://localhost" -ForegroundColor Green
Write-Host "验收: bash docker/verify.sh 或在 WSL 中运行" -ForegroundColor Green
Write-Host "查看: docker compose ps" -ForegroundColor Green
