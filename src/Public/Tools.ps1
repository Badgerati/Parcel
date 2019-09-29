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

    #TODO: test if admin user

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = './parcel.yml'
    }

    if (!(Test-Path $Path)) {
        throw "Parcel file not found: $($Path)"
    }

    $config = ConvertFrom-ParcelYaml -Path $Path
    $packages = ConvertTo-ParcelProviders -Packages $config.packages
    Invoke-ParcelPackages -Action Install -Packages $packages -Environment $Environment -IgnoreEnsures:$IgnoreEnsures
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

    #TODO: test if admin user

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = './parcel.yml'
    }

    if (!(Test-Path $Path)) {
        throw "Parcel file not found: $($Path)"
    }

    $config = ConvertFrom-ParcelYaml -Path $Path
    $packages = ConvertTo-ParcelProviders -Packages $config.packages
    Invoke-ParcelPackages -Action Uninstall -Packages $packages -Environment $Environment -IgnoreEnsures:$IgnoreEnsures
}