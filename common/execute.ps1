#!/usr/bin/env pwsh

param
(
    [Alias("Manifest", "Application")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $AppManifestPath,

    [Alias("Operations")]
    [Parameter(Mandatory=$false, Position=1)]
    [string] $OperationsManifestPath,

    [Alias("Config")]
    [Parameter(Mandatory=$true, Position=2)]
    [string] $ConfigPath,

    [Alias("Resources")]
    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=4)]
    [string] $Partition="root",

    [Parameter(Mandatory=$false, Position=5)]
    [string] $Task,

    [Parameter(Mandatory=$false, Position=6)]
    [string] $EnvironmentPrefix = "environment"
)

# Stop on error
$ErrorActionPreference = "Stop"

# Load common functions
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }
. "$($rootPath)/include.ps1"
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }

# Use single manifest if Operations manifest not set
if ($OperationsManifestPath -eq "") {
    $OperationsManifestPath = $AppManifestPath
}

# Set default parameter values
if (($ResourcePath -eq $null) -or ($ResourcePath -eq ""))
{
    $ResourcePath = ConvertTo-EnvResourcePath -ConfigPath $ConfigPath
}
if (($ResoucePrefix -eq $null) -or ($ResourcePrefix -eq "")) 
{ 
    $ResoucePrefix = $ConfigPrefix 
}
$packagePath = (Get-Item $AppManifestPath).Directory.FullName

# Read config and resources
$config = Read-EnvConfig -ConfigPath $ConfigPath
$resources = Read-EnvResources -ResourcePath $ResourcePath

# Check for and fill in templated vars in appManifest, then read the appManifest
$appManifestTemplatePath = $AppManifestPath
$AppManifestPath = "$rootPath/../temp/app_manifest.json"
Build-EnvTemplate -InputPath $appManifestTemplatePath -OutputPath $AppManifestPath -Params1 $config -Params2 $resources
$appManifest = Read-AppManifest -ManifestPath $AppManifestPath

# Check for and fill in templated vars in operationsManifest, then read the operationsManifest
$operationsManifestTemplatePath = $OperationsManifestPath
$OperationsManifestPath = "$rootPath/../temp/operations_manifest.json"
Build-EnvTemplate -InputPath $operationsManifestTemplatePath -OutputPath $OperationsManifestPath -Params1 $config -Params2 $resources
$operationsManifest = Read-AppManifest -ManifestPath $OperationsManifestPath

# Read applications array from resources file
$applications = Get-EnvMapValue -Map $resources -Key "applications"
if ($applications.Lenght -lt 2) {
    # Convert value to array if cmdlet returned an object 
    if ($applications -eq $null) {
        $applications = @()
    } else {
        $applications = @($applications)
    }
}

Write-Host "***** Performing $Task for application $($appManifest.name):$($appManifest.version) *****"

# Checking dependencies
$dependencies = $operationsManifest.dependencies
if (($task -ne "uninstall") -and ($dependencies -ne $null)) {
    Write-Host "`n***** Checking dependencies... *****`n"

    foreach ($dependency in $dependencies) {
        $dependencyFromResources = $applications | Where-Object {$_.name -eq $dependency.name}
        if ($dependencyFromResources -eq $null) {
            Write-Error "Dependency $($dependency.name):$($dependency.version) - Missing"
        } else {
            # Check version
            if (Test-AppVersion -Version $dependencyFromResources.version -Pattern $Dependency.version) {
                Write-Host "Dependency $($dependency.name):$($dependency.version) - OK"
            } else {
                Write-Error "Dependency $($dependency.name):$($dependency.version) - Installed wrong version ($($dependencyFromResources.version))"
            }
        }
    }
}

# Defining recipe
$recipes = $operationsManifest.$task

$universalRecipes = $false
if ($recipes -eq $null) {
    $recipes = $operationsManifest["operations"].$task
    $universalRecipes = $true
}
if ($recipes -eq $null) {
    throw "Manifest is missing $task declaration."   
}

# Find target environment in the operationsManifest
$envType = (Get-EnvMapValue -Map $resources -Key "$EnvironmentPrefix.type")
$envVersion = (Get-EnvMapValue -Map $resources -Key "$EnvironmentPrefix.version")
if ($envType -eq $null -or $envVersion -eq $null) {
    throw "Environment type or version is missing in resources"
}

# Check for env type
$targetRecipe = $null
foreach ($recipe in $recipes) {
    foreach ($env in $recipe.environments) {
        if ($env.name -eq $envType) {
            $targetRecipe = $recipe
            break
        }
    }
}
if ($targetRecipe -eq $null) {
    throw "There are no steps for environment $envType in the operationsManifest"
}

# Check for env version
foreach ($recipe in $recipes) {
    $operationsManifestRecipeEnv = $recipe.environments | Where-Object {$_.name -eq $envType}
    if (!(Test-AppVersion -Version $envVersion -Pattern $operationsManifestRecipeEnv.version)) {
        throw "Environment version ($envVersion) doesn't match pattern in operationsManifest ($($operationsManifestRecipeEnv.version))"
    }
}

Write-Host "`n***** Executing $Task actions for environment $envType... *****"

# Reverse uninstall steps for universal recipe (install-upgrade-uninstall)
$steps = $targetRecipe.steps
# if ($task -eq "uninstall" -and $universalRecipes) {
#     [array]::Reverse($steps)
# }

$stepNumber = 0
$actionType = $null
foreach ($step in $steps) {

    $stepNumber++
    $actionPath = $null
    $actionName = $null
    if ($step.action -ne $null) {
        $actionType = "standard"
        $actionName = $step.action
        $actionPath = "$rootPath/../$actionName"
    } elseif ($step["custom-action"] -ne $null) {
        $actionType = "custom"
        $actionName = $step["custom-action"]
        $actionPath = "$packagePath/$actionName"
    } else {
        throw "Step #$stepNumber is missing 'action' or 'custom-action' in the operationsManifest"
    }

    
    # # Skip on certain tasks
    # $executeOn = $step["execute-on"]
    # if ($executeOn -ne $null) {
    #     if (-not ($executeOn -contains $task)) {
    #         continue;
    #     }
    # }

    # Check if action exists
    if (-not (Test-Path -Path $actionPath)) {
        throw "$actionType action '$actionName' is not found at $actionPath."
    }
    if (-not (Test-Path -Path "$actionPath/run.ps1")) {
        throw "$actionType action '$actionName' does not support $Task steps"
    }

    # Define action parameters
    $actionParams = @{
        PackagePath=$packagePath;
        Partition=$Partition;
        TempPath="$rootPath/../temp"
    }

    Write-Host "`n***** Started $actionType action '$actionName' *****`n"

    . "$actionPath/run.ps1" -AppManifest $appManifest -operationsManifest $operationsManifest -Config $config -Resources $resources -Context $step -Params $actionParams

    Write-Host "`n***** Completed $actionType action '$actionName' *****"

}
