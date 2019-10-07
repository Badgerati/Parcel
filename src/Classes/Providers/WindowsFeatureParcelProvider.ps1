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
            return "DISM /Online /Enable-Feature /All /FeatureName:$($_package.Name) /NoRestart"
        }

        return "Add-WindowsFeature -Name $($_package.Name) -IncludeAllSubFeature -IncludeManagementTools -ErrorAction Stop"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) {
            return "DISM /online /Disable-feature /FeatureName:$($_package.Name) "
        }

        return "Remove-WindowsFeature -Name $($_package.Name) -IncludeManagementTools -ErrorAction Stop"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        return $null
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) 
        {
            
            write-host $_package.name
            $checkDismPackage = Invoke-Expression -Command "dism /online /get-featureinfo /featurename:$($_package.Name )" -ErrorAction Stop
            $checkDismPackageState = $checkDismPackage -imatch "State"
            write-host $checkDismPackageState
            if ($checkDismPackageState -ilike "*Disabled*")
            {
                return $false
            }
            else 
            {
                return $true
            }
        }
        else 
        {
        return ([bool](Get-WindowsFeature -Name $_package.Name -ErrorAction Ignore).Installed)
        }
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