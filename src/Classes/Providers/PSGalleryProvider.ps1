class PSGalleryParcelProvider : ParcelProvider
{
    PSGalleryParcelProvider([hashtable]$package) : base('PowerShell Gallery', 'All', $false) {}

    [bool] TestProviderInstalled()
    {
        if ((Get-Host).Version.Major -gt '5') {
            return $true
        }

        return ($null -ne (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore))
    }

    [scriptblock] GetProviderInstallScriptBlock()
    {
        return {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        }
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "Install-Module -Name $($_package.Name) -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "Uninstall-Module -Name $($_package.Name) -Force -AllVersions -ErrorAction Stop"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = (Get-Module -Name $_package.Name -ListAvailable | Where-Object { $_.Version -ieq $_package.Version })
        return ($result.Length -gt 0)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        return Invoke-Expression -Command "(Find-Module -Name $($_package.Name) $($this.GetSourceArgument($_package)) -ErrorAction Ignore).Version"
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ([string]::IsNullOrWhiteSpace($_package.Version) -or ($_package.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return "-RequiredVersion $($_package.Version)"
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        $_source = $_package.Source
        if ([string]::IsNullOrWhiteSpace($_source)) {
            $_source = 'PSGallery'
        }

        return "-Repository $($_source)"
    }

    #TODO: Source (repository)
    #TODO: get latest version!!
    #TODO: "args" support
}