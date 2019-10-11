class WindowsDISMParcelProvider : ParcelProvider
{
    WindowsDISMParcelProvider() : base('Windows DISM', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        if ($_context.os.type -ine 'windows') {
            throw 'Windows DISM is only supported on Windows...'
        }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "Invoke-Expression -Command 'dism /online /enable-feature /all /featurename:$($_package.Name) /norestart'"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "Invoke-Expression -Command 'dism /online /disable-feature /featurename:$($_package.Name)'"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $checkDismPackage = Invoke-Expression -Command "dism /online /get-featureinfo /featurename:$($_package.Name )" -ErrorAction Stop
        $checkDismPackageState = $checkDismPackage -imatch "State"
        return ($checkDismPackageState -inotlike "*Disabled*")
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

        return "/source $($_source)"
    }

  
}