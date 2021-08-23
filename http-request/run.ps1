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
$packagePath = $Params.PackagePath
$dataFile = $Context.data_file
if($dataFile -ne $null){
    $dataBody = Get-Content "$packagePath/$dataFile"
    try {
        (Invoke-WebRequest -UseBasicParsing $Context.url -ContentType "$($Context.content_type)" -Method $Context.verb -Body $dataBody).BaseResponse
    } catch {
        Write-Host "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response 
    }
} else {
    try {
        (Invoke-WebRequest -UseBasicParsing $Context.url -ContentType "$($Context.content_type)" -Method $Context.verb).BaseResponse
    } catch {
        Write-Host "An exception was caught: $($_.Exception.Message)"    
        $_.Exception.Response 
    }
}

