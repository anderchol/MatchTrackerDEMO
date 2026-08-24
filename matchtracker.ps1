# matchtracker.ps1
# WINDOWS ONLY

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

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
    Write-Host "Planning deployment..." -ForegroundColor Yellow
    tofu plan -var-file="terraform.tfvars" -out=tfplan
}

function Invoke-Deploy {
    tofu apply -auto-approve tfplan
    if ($LASTEXITCODE -eq 0) {
        tofu output
    }
}

function Invoke-Destroy {
    Write-Host "Deleting AWS resources..." -ForegroundColor Red
    Start-Sleep -Seconds 3
    tofu destroy -auto-approve
}

function Invoke-Check {
    $urls = tofu output -json health_urls | ConvertFrom-Json

    if (-not $urls) {
        Write-Host "Stack not deployed." -ForegroundColor Red
        return
    }

    foreach ($url in $urls) {
        Write-Host "`nChecking $url" -ForegroundColor Cyan
        try {
            Invoke-RestMethod $url | ConvertTo-Json -Depth 5
        }
        catch {
            Write-Host "Failed to connect." -ForegroundColor Red
        }
    }
}

function Invoke-SSH {
   $ips = tofu output -json instance_public_ips | ConvertFrom-Json

    for ($i = 0; $i -lt $ips.Count; $i++) {
        Write-Host "$($i+1)) $($ips[$i])"
    }

    $choice = [int](Read-Host "Instance number")

    ssh -i "$HOME\.ssh\matchtracker-key.pem" ec2-user@$($ips[$choice-1])
}

function Invoke-IP {
    $ip = Invoke-RestMethod https://ifconfig.me

    Write-Host ""
    Write-Host "Paste into terraform.tfvars:" -ForegroundColor Yellow
    Write-Host "your_ip = `"$ip/32`"" -ForegroundColor Green
}

function Invoke-DNS {
    $ips = tofu output -json instance_public_ips | ConvertFrom-Json

    if (-not $ips) {
        Write-Host "Stack not deployed." -ForegroundColor Red
        return
    }

    Write-Host "`nHosts entries:" -ForegroundColor Yellow

    for ($i = 0; $i -lt $ips.Count; $i++) {
        Write-Host "$($ips[$i]) matchtracker-$i.local" -ForegroundColor Green
    }
}

function Invoke-Status {

    $instances = aws ec2 describe-instances `
        --filters "Name=tag:Environment,Values=dev" `
                  "Name=instance-state-name,Values=running,pending,stopped" `
        --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" `
        --output table

    $instances
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
    default {
        Write-Host ""
        Write-Host "MatchTracker Commands" -ForegroundColor Cyan
        Write-Host "---------------------"
        Write-Host "dev      Run Flask locally"
        Write-Host "test     Run tests"
        Write-Host "init     Initialize Terraform/OpenTofu"
        Write-Host "plan     Create deployment plan"
        Write-Host "deploy   Apply deployment"
        Write-Host "destroy  Destroy infrastructure"
        Write-Host "check    Check all deployed servers"
        Write-Host "ssh      SSH into a selected server"
        Write-Host "ip       Show your public IP for terraform.tfvars"
        Write-Host "dns      Display hosts file entries"
        Write-Host "status   Show EC2 instance status"
    }
}