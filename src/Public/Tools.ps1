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
        $IgnoreEnsures
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

    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context
    $scripts = ConvertTo-ParcelScripts -Scripts $config.scripts
    Invoke-ParcelPackages -Action Install -Packages $packages -Scripts $scripts -Context $context -IgnoreEnsures:$IgnoreEnsures
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
        $IgnoreEnsures
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

    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context
    $scripts = ConvertTo-ParcelScripts -Scripts $config.scripts
    Invoke-ParcelPackages -Action Uninstall -Packages $packages -Scripts $scripts -Context $context -IgnoreEnsures:$IgnoreEnsures
}