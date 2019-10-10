class WindowsDISMParcelProvider : ParcelProvider
{
    WindowsDISMParcelProvider() : base('Windows DISM', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        if ($_context.os.type -ine 'windows') {
            throw 'Windows DISM is only supported on Windows.....'
        }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "Invoke-Expression -Command 'DISM /Online /Enable-Feature /All /FeatureName:$($_package.Name) /NoRestart'"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "Invoke-Expression -Command 'DISM /online /Disable-feature /FeatureName:$($_package.Name)'"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        return $null
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $checkDismPackage = Invoke-Expression -Command "dism /online /get-featureinfo /featurename:$($_package.Name )" -ErrorAction Stop
        $checkDismPackageState = $checkDismPackage -imatch "State"
        if ($checkDismPackageState -ilike "*Disabled*")
        {return $false}
        else 
        {return $true}
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

  
}