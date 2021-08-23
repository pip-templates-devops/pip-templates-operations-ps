#!/usr/bin/env pwsh

param
(
    [Alias("Manifest", "Application")]
    [Parameter(Mandatory=$true, Position=0)]
    [hashtable] $AppManifest,

    [Alias("Operations")]
    [Parameter(Mandatory=$false, Position=1)]
    [hashtable] $OperationsManifest,

    [Parameter(Mandatory=$true, Position=2)]
    [hashtable] $Config,

    [Parameter(Mandatory=$true, Position=3)]
    [hashtable] $Resources,

    [Parameter(Mandatory=$true, Position=4)]
    [hashtable] $Context,

    [Parameter(Mandatory=$true, Position=5)]
    [hashtable] $Params
)

# Reading parameters
$seconds = $Context.seconds
if ($seconds -eq $null) {
    $seconds = 1
}

Write-Host "Waiting $seconds seconds..."
Start-Sleep -Seconds $seconds