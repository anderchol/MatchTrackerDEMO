# matchtracker.ps1
param([Parameter(Position=0)][string]$Command = "help")
 
function Invoke-Dev {
    Write-Host "Starting MatchTracker at http://localhost:5000" -ForegroundColor Cyan
    $env:FLASK_HOST  = "0.0.0.0"
    $env:ENVIRONMENT = "local"
    $env:PORT        = "5000"
    python app/main.py
}
 
function Invoke-Test {
    pytest tests/ -v
}
 
function Invoke-Init {
    tofu init
}
 
function Invoke-Plan {
    Write-Host "Read this before deploying:" -ForegroundColor Yellow
    tofu plan
}
 
function Invoke-Deploy {
    tofu apply -auto-approve
    if ($LASTEXITCODE -eq 0) { tofu output }
}
 
function Invoke-Destroy {
    Write-Host "Deleting all AWS resources..." -ForegroundColor Red
    Start-Sleep -Seconds 3
    tofu destroy -auto-approve
}
 
function Invoke-Check {
    $url = tofu output -raw health_url 2>$null
    if (-not $url) { Write-Host "Stack not deployed" -ForegroundColor Red; exit 1 }
    Invoke-RestMethod -Uri $url | ConvertTo-Json -Depth 5
}
 
function Invoke-SSH {
    $cmd = tofu output -raw ssh_command 2>$null
    if (-not $cmd) { Write-Host "Stack not deployed" -ForegroundColor Red; exit 1 }
    Write-Host "Connecting: $cmd" -ForegroundColor Cyan
    Invoke-Expression $cmd
}
 
function Invoke-IP {
    $ip = Invoke-RestMethod -Uri "https://ifconfig.me"
    Write-Host "Paste into terraform.tfvars:" -ForegroundColor Yellow
    Write-Host "  your_ip = `"$ip/32`"" -ForegroundColor Green
}
 
function Invoke-DNS {
    $entry = tofu output -raw hosts_file_entry 2>$null
    if (-not $entry) { Write-Host "Stack not deployed" -ForegroundColor Red; exit 1 }
    Write-Host "Add to C:WindowsSystem32driversetchosts:" -ForegroundColor Yellow
    Write-Host "  $entry" -ForegroundColor Green
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrator")
    if ($isAdmin) {
        $confirm = Read-Host "Add automatically? (y/n)"
        if ($confirm -eq "y") { Add-Content "C:WindowsSystem32driversetchosts" $entry }
    } else { Write-Host "Rerun as Administrator to add automatically." -ForegroundColor Gray }
}
 
function Invoke-Status {
    $asg = tofu output -raw asg_name 2>$null
    aws autoscaling describe-auto-scaling-groups `
        --auto-scaling-group-names $asg `
        --query "AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState}" `
        --output table
}
 
switch ($Command.ToLower()) {
    "dev"     { Invoke-Dev }
    "test"    { Invoke-Test }
    "init"    { Invoke-Init }
    "plan"    { Invoke-Plan }
    "deploy"  { Invoke-Deploy }
    "destroy" { Invoke-Destroy }
    "check"   { Invoke-Check }
    "ssh"     { Invoke-SSH }
    "ip"      { Invoke-IP }
    "dns"     { Invoke-DNS }
    "status"  { Invoke-Status }
    default   { Write-Host "Commands: dev test init plan deploy destroy check ssh ip dns status" }
}
