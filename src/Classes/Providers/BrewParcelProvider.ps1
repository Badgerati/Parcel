class BrewParcelProvider : ParcelProvider
{
    BrewParcelProvider() : base('Brew', $false, 'brew') {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        $cmd = Get-Command -Name 'brew' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        $_script = "`$env:HOMEBREW_NO_AUTO_UPDATE = '1'; "

        if ($this.TestIsOnlineCask($_package)) {
            if ($_context.os.type -ine 'macos') {
                throw "Brew casks are only supported on MacOS"
            }

            $_script += "brew cask install --force $($_package.Name)"
        }
        else {
            $_script += "brew install --force $($_package.Name)"
        }

        return "$($_script) @PARCEL_NO_VERSION"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        if ($this.TestIsLocalCask($_package)) {
            return "brew cask uninstall --force $($_package.Name)"
        }
        else {
            return "brew uninstall --force $($_package.Name)"
        }
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = @(Invoke-Expression -Command "brew list --versions $($_package.Name)")
        $result = ($result -imatch "$($_package.Name)\s+$($this.GetVersionArgument($_package))")
        return (($result -imatch "$($_package.Name)\s+[0-9\._]+").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = @(Invoke-Expression -Command "brew list --versions $($_package.Name)")
        return (($result -imatch "$($_package.Name)\s+[0-9\._]+").Length -eq 0)
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

    [bool] TestIsOnlineCask([ParcelPackage]$_package)
    {
        $result = @(Invoke-Expression -Command "brew search --casks $($_package.Name)")
        return ($result[0] -ilike '*casks*')
    }

    [bool] TestIsLocalCask([ParcelPackage]$_package)
    {
        $result = @(Invoke-Expression -Command "brew cask list --versions $($_package.Name) 2>&1")
        return (($result -imatch "$($_package.Name)\s+[0-9\._]+").Length -gt 0)
    }
}