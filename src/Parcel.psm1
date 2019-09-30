# load private functions and classes
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

$classes = @(
    "$($root)/Classes/Enums/ParcelOSType.ps1",
    "$($root)/Classes/Enums/ParcelEnsureType.ps1",
    "$($root)/Classes/Enums/ParcelStatusType.ps1",
    "$($root)/Classes/ParcelStatus.ps1",
    "$($root)/Classes/ParcelScripts.ps1",
    "$($root)/Classes/ParcelPackage.ps1",
    "$($root)/Classes/Providers/ParcelProvider.ps1",
    "$($root)/Classes/Providers/ChocoProvider.ps1",
    "$($root)/Classes/Providers/PSGalleryProvider.ps1",
    "$($root)/Classes/Providers/ScoopProvider.ps1",
    "$($root)/Classes/ParcelFactory.ps1"
)

$classes | Resolve-Path | ForEach-Object { . $_ }

$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get existing functions from memory for later comparison
$sysfuncs = Get-ChildItem Function:

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)