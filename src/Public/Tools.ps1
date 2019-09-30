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

    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context
    Invoke-ParcelPackages -Action Install -Packages $packages -Context $context -IgnoreEnsures:$IgnoreEnsures
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

    $context = Get-ParcelContext -Environment $Environment
    $packages = ConvertTo-ParcelPackages -Packages $config.packages -Context $context
    Invoke-ParcelPackages -Action Uninstall -Packages $packages -Context $context -IgnoreEnsures:$IgnoreEnsures
}