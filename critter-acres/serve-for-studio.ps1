$root = 'C:\Users\Chun\Desktop\Roblox Game\critter-acres'
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add('http://localhost:34872/')
$l.Start()
while ($l.IsListening) {
  $ctx = $l.GetContext()
  $name = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
  $path = Join-Path $root $name
  if ($name -notmatch '\.\.' -and (Test-Path $path -PathType Leaf)) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ctx.Response.ContentType = 'text/plain; charset=utf-8'
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $ctx.Response.StatusCode = 404 }
  $ctx.Response.Close()
}
