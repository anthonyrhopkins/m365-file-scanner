# Microsoft 365 File Scanner - Local Server Launcher
# Run this script to start the file scanner in your browser

param(
    [int]$Port = 3000,
    [switch]$NoBrowser
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HtmlFile = "loop-file-scanner.html"
$FullPath = Join-Path $ScriptDir $HtmlFile

# Check if the HTML file exists
if (-not (Test-Path $FullPath)) {
    Write-Host "Error: $HtmlFile not found in $ScriptDir" -ForegroundColor Red
    exit 1
}

$Url = "http://localhost:$Port/"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Microsoft 365 File Scanner" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting local server..." -ForegroundColor Yellow
Write-Host "URL: $Url$HtmlFile" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Create HTTP listener
$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add($Url)

try {
    $Listener.Start()
    Write-Host "Server running!" -ForegroundColor Green

    # Open browser automatically unless -NoBrowser specified
    if (-not $NoBrowser) {
        $BrowserUrl = "$Url$HtmlFile"
        if ($IsMacOS) {
            Start-Process "open" -ArgumentList $BrowserUrl
        } elseif ($IsWindows) {
            Start-Process $BrowserUrl
        } else {
            # Linux
            Start-Process "xdg-open" -ArgumentList $BrowserUrl
        }
    }

    # Serve requests
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        # Get requested file path
        $RequestedPath = $Request.Url.LocalPath -replace '^/', ''
        if ([string]::IsNullOrEmpty($RequestedPath)) {
            $RequestedPath = $HtmlFile
        }

        $FilePath = Join-Path $ScriptDir $RequestedPath

        # Log request
        $Timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$Timestamp] $($Request.HttpMethod) /$RequestedPath" -ForegroundColor Gray

        if (Test-Path $FilePath -PathType Leaf) {
            # Determine content type
            $ContentType = switch -Regex ($FilePath) {
                '\.html?$' { 'text/html; charset=utf-8' }
                '\.css$'   { 'text/css; charset=utf-8' }
                '\.js$'    { 'application/javascript; charset=utf-8' }
                '\.json$'  { 'application/json; charset=utf-8' }
                '\.png$'   { 'image/png' }
                '\.jpg$'   { 'image/jpeg' }
                '\.gif$'   { 'image/gif' }
                '\.svg$'   { 'image/svg+xml' }
                '\.ico$'   { 'image/x-icon' }
                default    { 'application/octet-stream' }
            }

            $Content = [System.IO.File]::ReadAllBytes($FilePath)
            $Response.ContentType = $ContentType
            $Response.ContentLength64 = $Content.Length
            $Response.StatusCode = 200

            # Add CORS headers for local development
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
            $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")

            $Response.OutputStream.Write($Content, 0, $Content.Length)
        } else {
            # 404 Not Found
            $Response.StatusCode = 404
            $ErrorMessage = [System.Text.Encoding]::UTF8.GetBytes("404 - File Not Found: $RequestedPath")
            $Response.ContentType = "text/plain"
            $Response.OutputStream.Write($ErrorMessage, 0, $ErrorMessage.Length)
            Write-Host "  -> 404 Not Found" -ForegroundColor Red
        }

        $Response.Close()
    }
} catch {
    if ($_.Exception.Message -match "access is denied|address already in use") {
        Write-Host "Error: Port $Port is already in use. Try a different port:" -ForegroundColor Red
        Write-Host "  ./start-scanner.ps1 -Port 3001" -ForegroundColor Yellow
    } else {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} finally {
    if ($Listener) {
        $Listener.Stop()
        $Listener.Close()
        Write-Host "`nServer stopped." -ForegroundColor Yellow
    }
}
