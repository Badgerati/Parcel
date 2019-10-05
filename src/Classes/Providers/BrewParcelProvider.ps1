class BrewParcelProvider : ParcelProvider
{
    BrewParcelProvider() : base('Brew', $false, 'brew') {}

    [bool] TestProviderInstalled()
    {
        $cmd = Get-Command -Name 'brew' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetProviderInstallScriptBlock([hashtable]$_context)
    {
        throw [System.NotImplementedException]::new()
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "brew install --force $($_package.Name)"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "brew uninstall --force $($_package.Name)"
    }

    [string] GetProviderRemoveSourceScript([string]$_name)
    {
        throw [System.NotImplementedException]::new()
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        throw [System.NotImplementedException]::new()
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "brew list --versions $($_package.Name)"
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
        if ([string]::IsNullOrWhiteSpace($_package.Version) -or ($_package.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return $_package.Version
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        throw [System.NotImplementedException]::new()
    }
}