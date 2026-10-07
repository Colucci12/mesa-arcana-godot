$ErrorActionPreference = 'Stop'
$projetoJuno = Split-Path -Parent $PSScriptRoot
$configJuno = Join-Path $projetoJuno 'export_presets.cfg'
$modeloWeb = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'export_presets_web.cfg') -Raw
$configAtual = if (Test-Path -LiteralPath $configJuno) { Get-Content -LiteralPath $configJuno -Raw } else { '' }
# Configuração de rede e snapshots também precisam acompanhar os clientes nativos.
$configComDados = [regex]::Replace($configAtual, '(?m)^include_filter="([^"\r\n]*)"\r?$', {
    param($linhaFiltro)
    $filtrosJuno = @($linhaFiltro.Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($filtrosJuno -notcontains '*.cfg' -and $filtrosJuno -notcontains 'config/rede.cfg') { $filtrosJuno += 'config/rede.cfg' }
    if ($filtrosJuno -notcontains '*.json' -and $filtrosJuno -notcontains 'scripts/desenvolvimento/laboratorios/presets/*.json') { $filtrosJuno += 'scripts/desenvolvimento/laboratorios/presets/*.json' }
    'include_filter="' + ($filtrosJuno -join ',') + '"'
})
if ($configComDados -cne $configAtual) {
    Set-Content -LiteralPath $configJuno -Value $configComDados -Encoding utf8 -NoNewline
    $configAtual = $configComDados
    Write-Output 'Configuração de rede e snapshots incluídos nos presets; demais opções preservadas.'
}
if ($configAtual -notmatch '(?m)^name="Web"\r?$') {
    $indices = [regex]::Matches($configAtual, '\[preset\.(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }
    $indiceWeb = if ($indices.Count -gt 0) { ($indices | Measure-Object -Maximum).Maximum + 1 } else { 0 }
    $novoPreset = $modeloWeb.Replace('[preset.0', "[preset.$indiceWeb")
    Add-Content -LiteralPath $configJuno -Value ("`n" + $novoPreset) -Encoding utf8
    Write-Output 'Preset Web acrescentado; presets existentes preservados.'
} else {
    Write-Output 'Preset Web já existe; configuração preservada.'
}
New-Item -ItemType Directory -Path (Join-Path $projetoJuno 'build/web') -Force | Out-Null
