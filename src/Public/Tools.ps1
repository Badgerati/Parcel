function Install-ParcelPackages
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Environment,

        [switch]
        $IgnoreEnsures,

        [switch]
        $WhatIf
    )

    if (!(Test-ParcelAdminUser)) {
        throw 'Parcel needs to be run as an Administrator'
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = './parcel.yml'
    }

    if (!(Test-Path $Path)) {
        throw "Parcel file not found: $($Path)"
    }

    $config = ConvertFrom-ParcelYaml -Path $Path

    Write-Host ([string]::Empty)
    $scripts = ConvertTo-ParcelScripts -Scripts $config.scripts
    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context

    Invoke-ParcelPackages -Action Install -Packages $packages -Scripts $scripts -Providers $config.providers -Context $context -IgnoreEnsures:$IgnoreEnsures -WhatIf:$WhatIf
    Write-Host ([string]::Empty)
}

function Uninstall-ParcelPackages
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Environment,

        [switch]
        $IgnoreEnsures,

        [switch]
        $WhatIf
    )

    if (!(Test-ParcelAdminUser)) {
        throw 'Parcel needs to be run as an Administrator'
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = './parcel.yml'
    }

    if (!(Test-Path $Path)) {
        throw "Parcel file not found: $($Path)"
    }

    $config = ConvertFrom-ParcelYaml -Path $Path

    Write-Host ([string]::Empty)
    $scripts = ConvertTo-ParcelScripts -Scripts $config.scripts
    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context

    Invoke-ParcelPackages -Action Uninstall -Packages $packages -Scripts $scripts -Providers $config.providers -Context $context -IgnoreEnsures:$IgnoreEnsures -WhatIf:$WhatIf
    Write-Host ([string]::Empty)
}