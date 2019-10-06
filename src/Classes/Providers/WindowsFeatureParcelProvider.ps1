class WindowsFeatureParcelProvider : ParcelProvider
{
    WindowsFeatureParcelProvider() : base('Windows Feature', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        if ($_context.os.type -ine 'windows') {
            throw 'Windows Features are only supported on Windows'
        }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) {
            return "Enable-WindowsOptionalFeature -FeatureName $($_package.Name) -NoRestart -All -Online -ErrorAction Stop"
        }

        return "Add-WindowsFeature -Name $($_package.Name) -IncludeAllSubFeature -IncludeManagementTools -ErrorAction Stop"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) {
            return "Disable-WindowsOptionalFeature -FeatureName $($_package.Name) -NoRestart -Online -ErrorAction Stop"
        }

        return "Remove-WindowsFeature -Name $($_package.Name) -IncludeManagementTools -ErrorAction Stop"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        return $null
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) {
            return ((Get-WindowsOptionalFeature -Online -FeatureName $_package.Name -ErrorAction Ignore).State -ieq 'enabled')
        }

        return ([bool](Get-WindowsFeature -Name $_package.Name -ErrorAction Ignore).Installed)
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        $_source = $_package.Source
        if ([string]::IsNullOrWhiteSpace($_source)) {
            $_source = $this.DefaultSource
        }

        if ([string]::IsNullOrWhiteSpace($_source)) {
            return [string]::Empty
        }

        return "-Source $($_source)"
    }

    [bool] IsOptionalFeature([ParcelPackage]$_package)
    {
        $optional = $true
        if ($null -ne (Get-Command -Name 'Get-WindowsFeature' -ErrorAction Ignore)) {
            $optional = ($null -eq (Get-WindowsFeature -Name $_package.Name -ErrorAction Ignore))
        }

        return $optional
    }
}