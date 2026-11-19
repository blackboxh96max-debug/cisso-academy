# TEST : emballe le build Windows Flutter (exe + DLL + data\) dans un seul .exe
# avec Enigma Virtual Box. Les fichiers restent dans l'exe et sont lus en
# mémoire (virtualisation des API fichiers), rien n'est extrait sur le disque.
param(
  [Parameter(Mandatory = $true)] [string] $ReleaseDir,
  [Parameter(Mandatory = $true)] [string] $OutputExe,
  [Parameter(Mandatory = $true)] [string] $EvbConsole
)
$ErrorActionPreference = 'Stop'
$ReleaseDir = (Resolve-Path $ReleaseDir).Path
$mainExe = Join-Path $ReleaseDir 'cisso_academy.exe'
if (-not (Test-Path $mainExe)) { throw "Introuvable : $mainExe" }

function Esc([string] $s) { [System.Security.SecurityElement]::Escape($s) }

function Entries([string] $dir, [string] $indent) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($d in Get-ChildItem -LiteralPath $dir -Directory | Sort-Object Name) {
    [void]$sb.AppendLine("$indent<File>")
    [void]$sb.AppendLine("$indent  <Type>3</Type>")
    [void]$sb.AppendLine("$indent  <Name>$(Esc $d.Name)</Name>")
    [void]$sb.AppendLine("$indent  <Action>0</Action>")
    [void]$sb.AppendLine("$indent  <OverwriteDateTime>False</OverwriteDateTime>")
    [void]$sb.AppendLine("$indent  <OverwriteAttributes>False</OverwriteAttributes>")
    [void]$sb.AppendLine("$indent  <HideFromDialogs>0</HideFromDialogs>")
    [void]$sb.AppendLine("$indent  <Files>")
    [void]$sb.Append((Entries $d.FullName "$indent    "))
    [void]$sb.AppendLine("$indent  </Files>")
    [void]$sb.AppendLine("$indent</File>")
  }
  foreach ($f in Get-ChildItem -LiteralPath $dir -File | Sort-Object Name) {
    if ($f.FullName -eq $mainExe) { continue }
    [void]$sb.AppendLine("$indent<File>")
    [void]$sb.AppendLine("$indent  <Type>2</Type>")
    [void]$sb.AppendLine("$indent  <Name>$(Esc $f.Name)</Name>")
    [void]$sb.AppendLine("$indent  <File>$(Esc $f.FullName)</File>")
    [void]$sb.AppendLine("$indent  <ActiveX>False</ActiveX>")
    [void]$sb.AppendLine("$indent  <ActiveXInstall>False</ActiveXInstall>")
    [void]$sb.AppendLine("$indent  <Action>0</Action>")
    [void]$sb.AppendLine("$indent  <OverwriteDateTime>False</OverwriteDateTime>")
    [void]$sb.AppendLine("$indent  <OverwriteAttributes>False</OverwriteAttributes>")
    [void]$sb.AppendLine("$indent  <PassCommandLine>False</PassCommandLine>")
    [void]$sb.AppendLine("$indent  <HideFromDialogs>0</HideFromDialogs>")
    [void]$sb.AppendLine("$indent</File>")
  }
  $sb.ToString()
}

$OutputExe = [System.IO.Path]::GetFullPath($OutputExe)
$project = @"
<?xml version="1.0" encoding="windows-1252"?>
<>
  <InputFile>$(Esc $mainExe)</InputFile>
  <OutputFile>$(Esc $OutputExe)</OutputFile>
  <Files>
    <Enabled>True</Enabled>
    <DeleteExtractedOnExit>False</DeleteExtractedOnExit>
    <CompressFiles>False</CompressFiles>
    <Files>
      <File>
        <Type>3</Type>
        <Name>%DEFAULT FOLDER%</Name>
        <Action>0</Action>
        <OverwriteDateTime>False</OverwriteDateTime>
        <OverwriteAttributes>False</OverwriteAttributes>
        <HideFromDialogs>0</HideFromDialogs>
        <Files>
$(Entries $ReleaseDir '          ')        </Files>
      </File>
    </Files>
  </Files>
  <Registries>
    <Enabled>False</Enabled>
  </Registries>
  <Packaging>
    <Enabled>False</Enabled>
  </Packaging>
  <Options>
    <ShareVirtualSystem>False</ShareVirtualSystem>
    <MapExecutableWithTemporaryFile>False</MapExecutableWithTemporaryFile>
    <TemporaryFileMask/>
    <AllowRunningOfVirtualExeFiles>False</AllowRunningOfVirtualExeFiles>
    <ProcessesOfAnyPlatforms>False</ProcessesOfAnyPlatforms>
  </Options>
  <Storage>
    <Files>
      <Enabled>False</Enabled>
      <Folder>%DEFAULT FOLDER%\</Folder>
      <RandomFileNames>False</RandomFileNames>
      <EncryptContent>False</EncryptContent>
    </Files>
  </Storage>
</>
"@
$evb = Join-Path $env:RUNNER_TEMP 'cisso_portable.evb'
[System.IO.File]::WriteAllText($evb, $project, [System.Text.Encoding]::GetEncoding(1252))
Write-Host "Projet EVB : $evb"
& $EvbConsole $evb
if (-not (Test-Path $OutputExe)) { throw "Enigma Virtual Box n'a pas produit $OutputExe" }
$size = [math]::Round((Get-Item $OutputExe).Length / 1MB, 1)
Write-Host "Exe portable : $OutputExe ($size Mo)"
