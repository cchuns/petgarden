# Critter Editor helper: serves the editor page and its data files on http://localhost:34880/
# Start it with "Start Critter Editor.bat". Keep this window open while you edit or sync; close it to stop.
#   GET  /                       the editor page (index.html)
#   GET  /api/data               all data files in one bundle (the editor and the CritterSync plugin read this)
#   GET  /api/version            {"version": n}, goes up on every save (the plugin's auto-pull watches it)
#   PUT  /api/data/<name>        save one data file (a backup of the old one goes to data/history)
#   GET/POST /api/studio         what the plugin last saw in Studio (models present, synced version)
#   PUT  /api/model/<kind>/<id>.<ext>   save an uploaded 3D model file into models/<kind>/
param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataDir = Join-Path $root 'data'
$histDir = Join-Path $dataDir 'history'
$modelDir = Join-Path $root 'models'
$names = @('weapons', 'pets', 'eggs', 'capsules', 'skills', 'decor', 'tags')
$port = 34880
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($d in @($dataDir, $histDir, $modelDir, (Join-Path $modelDir 'weapons'), (Join-Path $modelDir 'pets'))) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
$verFile = Join-Path $dataDir 'version.txt'
if (-not (Test-Path $verFile)) { [IO.File]::WriteAllText($verFile, '1', $utf8) }

function Get-Version { [int64]([IO.File]::ReadAllText($verFile).Trim()) }

function Send($ctx, [int]$code, [string]$type, [byte[]]$bytes) {
  $r = $ctx.Response
  $r.StatusCode = $code
  $r.ContentType = $type
  $r.Headers.Add('Cache-Control', 'no-store')
  $r.ContentLength64 = $bytes.Length
  $r.OutputStream.Write($bytes, 0, $bytes.Length)
  $r.Close()
}
function SendText($ctx, [int]$code, [string]$type, [string]$text) { Send $ctx $code $type ($utf8.GetBytes($text)) }
function SendJson($ctx, [int]$code, [string]$json) { SendText $ctx $code 'application/json; charset=utf-8' $json }
function ReadBody($ctx) {
  $ms = New-Object System.IO.MemoryStream
  $ctx.Request.InputStream.CopyTo($ms)
  return ,$ms.ToArray()
}
function Esc([string]$s) { return ($s -replace '\\', '\\' -replace '"', '\"') }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
try { $listener.Start() } catch {
  Write-Host "Could not start on port $port. Is the Critter Editor already open in another window?" -ForegroundColor Red
  Read-Host 'Press Enter to close'
  exit 1
}
Write-Host ''
Write-Host '  Critter Editor is running at http://localhost:34880/' -ForegroundColor Green
Write-Host '  Keep this window open while you edit or sync. Close it to stop.'
Write-Host ''
if (-not $NoBrowser) { Start-Process "http://localhost:$port/" }

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $method = $ctx.Request.HttpMethod
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
      Send $ctx 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes((Join-Path $root 'index.html')))
    }
    elseif ($method -eq 'GET' -and $path -eq '/api/version') {
      SendJson $ctx 200 ('{"version":' + (Get-Version) + '}')
    }
    elseif ($method -eq 'GET' -and $path -eq '/api/data') {
      $parts = @('"version":' + (Get-Version))
      foreach ($n in $names) {
        $f = Join-Path $dataDir "$n.json"
        $txt = if (Test-Path $f) { [IO.File]::ReadAllText($f, $utf8) } else { '[]' }
        $parts += ('"' + $n + '":' + $txt)
      }
      SendJson $ctx 200 ('{' + ($parts -join ',') + '}')
    }
    elseif ($method -eq 'PUT' -and $path -match '^/api/data/([a-z]+)$' -and $names -contains $Matches[1]) {
      $n = $Matches[1]
      $bytes = ReadBody $ctx
      $text = $utf8.GetString($bytes)
      $null = $text | ConvertFrom-Json # refuse anything that isn't valid JSON
      $f = Join-Path $dataDir "$n.json"
      if (Test-Path $f) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $f (Join-Path $histDir "$n-$stamp.json") -Force
        Get-ChildItem $histDir -Filter "$n-*.json" | Sort-Object Name -Descending | Select-Object -Skip 40 | Remove-Item -Force
      }
      [IO.File]::WriteAllBytes($f, $bytes)
      $v = (Get-Version) + 1
      [IO.File]::WriteAllText($verFile, "$v", $utf8)
      Write-Host ("  saved {0}.json  (version {1})" -f $n, $v)
      SendJson $ctx 200 ('{"ok":true,"version":' + $v + '}')
    }
    elseif ($method -eq 'GET' -and $path -eq '/api/studio') {
      $f = Join-Path $dataDir '_studio.json'
      SendJson $ctx 200 $(if (Test-Path $f) { [IO.File]::ReadAllText($f, $utf8) } else { '{}' })
    }
    elseif ($method -eq 'POST' -and $path -eq '/api/studio') {
      $bytes = ReadBody $ctx
      $null = $utf8.GetString($bytes) | ConvertFrom-Json
      [IO.File]::WriteAllBytes((Join-Path $dataDir '_studio.json'), $bytes)
      SendJson $ctx 200 '{"ok":true}'
    }
    elseif ($method -eq 'PUT' -and $path -match '^/api/model/(weapons|pets)/([A-Za-z0-9_]+)\.(fbx|obj|glb|gltf)$') {
      $kind, $id, $ext = $Matches[1], $Matches[2], $Matches[3].ToLower()
      $bytes = ReadBody $ctx
      Get-ChildItem (Join-Path $modelDir $kind) -Filter "$id.*" | Remove-Item -Force
      $f = Join-Path (Join-Path $modelDir $kind) "$id.$ext"
      [IO.File]::WriteAllBytes($f, $bytes)
      Write-Host ("  model saved: models\{0}\{1}.{2}" -f $kind, $id, $ext)
      SendJson $ctx 200 ('{"ok":true,"file":"' + (Esc "$kind/$id.$ext") + '","path":"' + (Esc $f) + '"}')
    }
    elseif ($method -eq 'GET' -and $path -eq '/api/models') {
      $list = @()
      foreach ($k in @('weapons', 'pets')) {
        foreach ($file in Get-ChildItem (Join-Path $modelDir $k) -File) { $list += ('"' + (Esc "$k/$($file.Name)") + '"') }
      }
      SendJson $ctx 200 ('{"folder":"' + (Esc $modelDir) + '","files":[' + ($list -join ',') + ']}')
    }
    else { SendJson $ctx 404 '{"error":"not found"}' }
  } catch {
    Write-Host ("  error: " + $_.Exception.Message) -ForegroundColor Yellow
    try { SendJson $ctx 400 ('{"error":"' + (Esc $_.Exception.Message) + '"}') } catch {}
  }
}
