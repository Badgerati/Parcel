class WindowsFeatureParcelProvider : ParcelProvider
{
    WindowsFeatureParcelProvider() : base('Windows Feature', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        if ($_context.os.type -ine 'windows') {
            throw 'Windows Features are only supported on Windows'
        }

        # if ((Get-Host).Version.Major -gt '5') {
        #     throw "Windows Features is only supported on PS5.0"
        # }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        if ($this.IsOptionalFeature($_package)) {
            return "DISM /Online /Enable-Feature /All /FeatureName:$($_package.Name) /NoRestart -ErrorAction Stop"
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
            $checkDismPackage = dism /online /get-featureinfo /featurename:$_package.Name 
            $checkDismPackageState = $checkDismPackage -match "State"
            if ($checkDismPackageState -like "*Disabled*")
            {
                $checkDismPackageResult = $false
                }
            else {
                $checkDismPackageResult = $true
            }
            
         
            return $checkDismPackageResult
        }
        else {
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