# Docker 集群一键启动（Windows PowerShell）
$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot -Parent
Set-Location $RootDir

if (-not (Test-Path ".env")) {
    Copy-Item "docker\.env.example" ".env"
    Write-Host "已创建 .env，请按需修改数据库密码后重新运行。" -ForegroundColor Yellow
}

Write-Host "开始构建并启动 Docker 集群..." -ForegroundColor Cyan
docker compose up -d --build

Write-Host ""
Write-Host "集群启动中，可用以下命令查看状态：" -ForegroundColor Green
Write-Host "  docker compose ps"
Write-Host "  docker compose logs -f warehouse-web warehouse-gateway"
Write-Host ""
Write-Host "Web 访问: http://localhost" -ForegroundColor Green
Write-Host "Nacos:    http://localhost:8848/nacos" -ForegroundColor Green
