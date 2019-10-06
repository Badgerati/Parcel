class BrewParcelProvider : ParcelProvider
{
    BrewParcelProvider() : base('Brew', $false, 'brew') {}

    [bool] TestProviderInstalled()
    {
        $cmd = Get-Command -Name 'brew' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "brew install --force $($_package.Name)"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "brew uninstall --force $($_package.Name)"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "`$env:HOMEBREW_NO_AUTO_UPDATE = '1'; brew list --versions $($_package.Name)"
        $result = ($result -imatch "$($_package.Name)\s+$($this.GetVersionArgument($_package))")
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\._]+").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "brew list --versions $($_package.Name)"
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\._]+").Length -eq 0)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        return [string]::Empty
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ($_package.IsLatest) {
            return [string]::Empty
        }

        return $_package.Version
    }
}