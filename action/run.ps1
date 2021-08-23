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
$param1 = $Context.param1
$param2 = $Context.param2

# Do something useful here...
Write-Host "Processing..."
Write-Host "Param1=$param1, Param2=$param2"
Start-Sleep -Seconds 1
