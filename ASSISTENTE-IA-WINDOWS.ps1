param([switch]$Check, [switch]$Help)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$version = '1.0'
$state = if ($env:ASSISTENTE_STATE_DIR) { $env:ASSISTENTE_STATE_DIR } else { Join-Path $env:LOCALAPPDATA 'Assistente IA' }
$langFile = Join-Path $state 'language'
$script:lang = if ($env:ASSISTENTE_LANG -in @('en', 'pt-BR')) { $env:ASSISTENTE_LANG } elseif (Test-Path -LiteralPath $langFile) { (Get-Content -LiteralPath $langFile -TotalCount 1 -Encoding UTF8).Trim() } elseif ([Globalization.CultureInfo]::CurrentUICulture.Name -like 'en*') { 'en' } else { 'pt-BR' }
if ($script:lang -notin @('en', 'pt-BR')) { $script:lang = 'pt-BR' }
function T([string]$pt, [string]$en) { if ($script:lang -eq 'en') { $en } else { $pt } }
function Read-Choice([string]$pt, [string]$en) { Read-Host (T $pt $en) }
function Save-Text([string]$path, [string]$value) {
  $parent = Split-Path -Parent $path
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  $temp = Join-Path $parent ([IO.Path]::GetRandomFileName())
  try { [IO.File]::WriteAllText($temp, $value + "`n", [Text.UTF8Encoding]::new($false)); Move-Item -LiteralPath $temp -Destination $path -Force }
  finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}
function Header([string]$title) { Clear-Host; Write-Host "`n  ASSISTENTE IA · WINDOWS $version" -ForegroundColor Cyan; Write-Host "  $title"; Write-Host ('  ' + ('─' * 54)) }
function Pause-Menu { [void](Read-Host (T 'Enter para voltar' 'Press Enter to go back')) }
function Existing-Directory([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $null }
  $path = [Environment]::ExpandEnvironmentVariables($path.Trim().Trim('"'))
  if ($path.StartsWith('~')) { $path = Join-Path $HOME $path.Substring(1).TrimStart('\', '/') }
  if (-not (Test-Path -LiteralPath $path -PathType Container)) { Write-Warning (T 'Pasta não encontrada.' 'Folder not found.'); return $null }
  (Resolve-Path -LiteralPath $path).ProviderPath
}
function Project-Tool([string]$path) {
  $profile = Join-Path $path '.assistente-ia\tool'
  if (Test-Path -LiteralPath $profile -PathType Leaf) {
    $value = (Get-Content -LiteralPath $profile -TotalCount 1 -Encoding UTF8).Trim()
    if ($value -in @('codex', 'claude')) { return $value }
  }
  return $null
}
function Select-Tool([string]$path) {
  $tool = Project-Tool $path
  if ($tool) { return $tool }
  Write-Host (T '1) Codex CLI  2) Claude Code' '1) Codex CLI  2) Claude Code')
  $choice = Read-Choice 'Ferramenta' 'Agent'
  $tool = switch ($choice) { '1' { 'codex' } '2' { 'claude' } default { $null } }
  if ($tool) { Save-Text (Join-Path $path '.assistente-ia\tool') $tool }
  return $tool
}
function Set-Project([string]$path) {
  $script:project = Existing-Directory $path
  if (-not $script:project) { return }
  Save-Text (Join-Path $state 'current') $script:project
  $recentFile = Join-Path $state 'recents'
  $recent = @($script:project)
  if (Test-Path -LiteralPath $recentFile) { $recent += @(Get-Content -LiteralPath $recentFile -Encoding UTF8 | Where-Object { $_ -and $_ -ne $script:project -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 19) }
  Save-Text $recentFile ($recent -join "`n")
}
function Choose-Directory {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = T 'Escolha a pasta do projeto' 'Choose the project folder'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
  } catch { return $null }
  return $null
}
function Project-Menu {
  Header (T 'Projetos' 'Projects')
  Write-Host (T '1) Criar projeto  2) Abrir pasta  3) Recentes  0) Voltar' '1) Create project  2) Open folder  3) Recent  0) Back')
  $choice = Read-Choice 'Escolha' 'Choose'
  switch ($choice) {
    '1' {
      $parent = Choose-Directory
      if (-not $parent) { $parent = Read-Choice 'Pasta onde criar' 'Parent folder' }
      $parent = Existing-Directory $parent
      if (-not $parent) { return }
      $name = Read-Choice 'Nome do projeto' 'Project name'
      if ($name -notmatch '^[^\\/:*?"<>|.][^\\/:*?"<>|]{0,119}$' -or $name -in @('.', '..')) { Write-Warning (T 'Nome inválido.' 'Invalid name.'); return }
      Write-Host (T '1) Codex CLI  2) Claude Code' '1) Codex CLI  2) Claude Code')
      $tool = switch (Read-Choice 'Ferramenta' 'Agent') { '1' { 'codex' } '2' { 'claude' } default { $null } }
      if (-not $tool) { return }
      $group = if ($tool -eq 'codex') { 'CODEX' } else { 'CLAUDE' }
      $path = Join-Path (Join-Path $parent $group) $name
      if (Test-Path -LiteralPath $path) { Write-Warning (T 'A pasta já existe.' 'Folder already exists.'); return }
      Write-Host "$path"
      if ((Read-Choice 'Enter para criar; 0 cancela' 'Enter to create; 0 cancels') -eq '0') { return }
      New-Item -ItemType Directory -Path $path -Force | Out-Null
      Save-Text (Join-Path $path '.assistente-ia\tool') $tool
      foreach ($folder in @('INSTRUCOES', 'PROMPTS', 'ANEXOS', 'DOCS', 'CODIGO')) { New-Item -ItemType Directory -Path (Join-Path $path $folder) -Force | Out-Null }
      Save-Text (Join-Path $path 'INSTRUCOES\PROJETO.md') (T '# Instruções do projeto' '# Project instructions')
      $pointer = if ($tool -eq 'codex') { 'AGENTS.md' } else { 'CLAUDE.md' }
      Save-Text (Join-Path $path $pointer) (T 'Leia INSTRUCOES/PROJETO.md antes de trabalhar neste projeto.' 'Read INSTRUCOES/PROJETO.md before working on this project.')
      Set-Project $path
    }
    '2' {
      $path = Choose-Directory
      if (-not $path) { $path = Read-Choice 'Caminho da pasta' 'Folder path' }
      if ($path) { Set-Project $path }
    }
    '3' {
      $file = Join-Path $state 'recents'
      if (-not (Test-Path -LiteralPath $file)) { Write-Host (T 'Sem projetos recentes.' 'No recent projects.'); return }
      $paths = @(Get-Content -LiteralPath $file -Encoding UTF8 | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
      for ($i = 0; $i -lt $paths.Count; $i++) { Write-Host "$($i + 1)) $($paths[$i])" }
      $pick = Read-Choice 'Número (0 cancela)' 'Number (0 cancels)'
      if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $paths.Count) { Set-Project $paths[[int]$pick - 1] }
    }
  }
}
function Agent-Menu([string]$mode) {
  if (-not $script:project) { Project-Menu; if (-not $script:project) { return } }
  $tool = Select-Tool $script:project
  if (-not $tool) { return }
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { Write-Warning (T "Instale e autentique $tool primeiro." "Install and sign in to $tool first."); return }
  $workmode = Read-Choice 'Modo: 1) trabalhar  2) planejar [1]' 'Mode: 1) work  2) plan [1]'
  $argsList = @()
  if ($tool -eq 'codex') {
    if ($mode -eq 'resume') { $argsList += @('resume', '--last') }
    if ($mode -eq 'select') { $argsList += 'resume' }
    $argsList += @('--cd', $script:project, '--ask-for-approval', 'on-request', '--sandbox')
    $argsList += $(if ($workmode -eq '2') { 'read-only' } else { 'workspace-write' })
  } else {
    if ($mode -eq 'resume') { $argsList += '--continue' }
    if ($mode -eq 'select') { $argsList += '--resume' }
    $argsList += @('--permission-mode', $(if ($workmode -eq '2') { 'plan' } else { 'default' }))
  }
  if ($mode -eq 'new') {
    Write-Host (T '1) Escrever pedido  2) Usar arquivo .md/.txt  3) Sem pedido' '1) Write prompt  2) Use .md/.txt file  3) No prompt')
    $promptChoice = Read-Choice 'Escolha [3]' 'Choose [3]'
    $promptText = ''
    if ($promptChoice -eq '1') { Write-Host (T 'Escreva o pedido; FIM/DONE encerra.' 'Write the prompt; FIM/DONE finishes.'); $lines = @(); while ($true) { $line = Read-Host '> '; if ($line -in @('FIM', 'DONE')) { break }; $lines += $line; if (($lines -join "`n").Length -gt 60000) { Write-Warning (T 'Pedido muito longo.' 'Prompt too long.'); return } }; $promptText = $lines -join "`n" }
    if ($promptChoice -eq '2') { $file = Read-Choice 'Caminho do arquivo' 'File path'; if ($file -notmatch '\.(md|txt)$' -or -not (Test-Path -LiteralPath $file -PathType Leaf)) { Write-Warning (T 'Arquivo inválido.' 'Invalid file.'); return }; $promptText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $file).ProviderPath); if ($promptText.Length -gt 60000) { Write-Warning (T 'Arquivo muito longo.' 'File too long.'); return } }
    if ($promptText) { $argsList += @('--', $promptText) }
  }
  Write-Host "`n$tool $($argsList -join ' ')"
  if ((Read-Choice 'Enter para começar; 0 cancela' 'Enter to start; 0 cancels') -eq '0') { return }
  Push-Location -LiteralPath $script:project
  try { & $tool @argsList }
  finally { Pop-Location }
}
function Care-Menu {
  if (-not $script:project) { Project-Menu; if (-not $script:project) { return } }
  Header (T 'Cuidar do projeto' 'Project care')
  Write-Host (T '1) Abrir pasta  2) Editar instruções  3) Abrir prompts  4) Git  5) ZIP  6) Servidor npm' '1) Open folder  2) Edit instructions  3) Open prompts  4) Git  5) ZIP  6) npm server')
  $choice = Read-Choice 'Escolha' 'Choose'
  switch ($choice) {
    '1' { Start-Process -FilePath $script:project }
    '2' { $file = Join-Path $script:project 'INSTRUCOES\PROJETO.md'; if (-not (Test-Path -LiteralPath $file)) { Save-Text $file (T '# Instruções do projeto' '# Project instructions') }; Start-Process notepad.exe -ArgumentList ('"{0}"' -f $file) }
    '3' { $path = Join-Path $script:project 'PROMPTS'; New-Item -ItemType Directory -Path $path -Force | Out-Null; Start-Process -FilePath $path }
    '4' { if (Get-Command git -ErrorAction SilentlyContinue) { & git -C $script:project status --short --branch } else { Write-Warning 'Git unavailable' } }
    '5' { $parent = Choose-Directory; if (-not $parent) { return }; if ($parent -eq $script:project -or $parent.StartsWith($script:project + '\', [StringComparison]::OrdinalIgnoreCase)) { Write-Warning (T 'Escolha uma pasta fora do projeto.' 'Choose a folder outside the project.'); return }; $dest = Join-Path $parent ((Split-Path $script:project -Leaf) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip'); if ((Read-Choice ("$dest - " + (T 'Enter para criar; 0 cancela' 'Enter to create; 0 cancels')) '') -eq '0') { return }; Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory($script:project, $dest, [IO.Compression.CompressionLevel]::Optimal, $true); Write-Host $dest }
    '6' { if (Test-Path -LiteralPath (Join-Path $script:project 'package.json')) { Push-Location -LiteralPath $script:project; try { & npm run dev } finally { Pop-Location } } else { Write-Warning 'package.json unavailable' } }
  }
}
function Settings-Menu {
  Header (T 'Idioma e diagnóstico' 'Language and diagnostics')
  Write-Host '1) Português (Brasil)  2) English  3) Diagnóstico / Diagnostics'
  switch (Read-Choice 'Escolha' 'Choose') {
    '1' { $script:lang = 'pt-BR'; Save-Text $langFile $script:lang }
    '2' { $script:lang = 'en'; Save-Text $langFile $script:lang }
    '3' { Write-Host "PowerShell $($PSVersionTable.PSVersion)"; Write-Host "State: $state"; foreach ($tool in @('codex', 'claude', 'git', 'npm')) { $cmd = Get-Command $tool -ErrorAction SilentlyContinue; Write-Host "${tool}: $(if ($cmd) { $cmd.Source } else { 'unavailable' })" } }
  }
}
if ($Help) { Write-Host "Assistente IA Windows $version`n.\ASSISTENTE-IA-WINDOWS.cmd`n-check: verify PowerShell source"; return }
if ($Check) { Write-Host "Assistente IA Windows $version - PowerShell source loaded successfully"; return }
New-Item -ItemType Directory -Path $state -Force | Out-Null
$script:project = $null
$currentFile = Join-Path $state 'current'
if (Test-Path -LiteralPath $currentFile) { $saved = (Get-Content -LiteralPath $currentFile -TotalCount 1 -Encoding UTF8).Trim(); if (Test-Path -LiteralPath $saved -PathType Container) { $script:project = $saved } }
while ($true) {
  Header (T 'Painel' 'Dashboard')
  Write-Host "  $(T 'Projeto' 'Project'): $(if ($script:project) { $script:project } else { T 'nenhum' 'none' })"
  Write-Host (T ' 1) Continuar  2) Nova conversa  3) Escolher conversa antiga' ' 1) Resume  2) New conversation  3) Choose older conversation')
  Write-Host (T ' 4) Projetos  5) Cuidar do projeto  6) Idioma e diagnóstico  0) Sair' ' 4) Projects  5) Project care  6) Language and diagnostics  0) Exit')
  switch (Read-Choice 'Escolha' 'Choose') {
    '1' { Agent-Menu 'resume'; Pause-Menu }
    '2' { Agent-Menu 'new'; Pause-Menu }
    '3' { Agent-Menu 'select'; Pause-Menu }
    '4' { Project-Menu; Pause-Menu }
    '5' { Care-Menu; Pause-Menu }
    '6' { Settings-Menu; Pause-Menu }
    '0' { return }
  }
}
