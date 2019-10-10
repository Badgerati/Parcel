class AptGetParcelProvider : ParcelProvider
{
    AptGetParcelProvider() : base('Apt-Get', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        # fail if apt-get isn't available
        if ($null -eq (Get-Command -Name 'apt-get' -ErrorAction Ignore)) {
            throw 'The provider apt-get is not installed'
        }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "sudo apt-get install --yes $($_package.Name)=$($this.GetVersionArgument($_package)) 2>&1"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "sudo apt-get remove --purge --yes $($_package.Name) 2>&1"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        return $null
    }

    [string] GetProviderRemoveSourceScript([string]$_name, [string]$_url)
    {
        return $null
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = (Invoke-Expression -Command "`$r = dpkg -s $($_package.Name) 2>&1; if (!`$?) { return `$null }; return `$r")
        if ($null -eq $result) {
            return $false
        }

        return (($result -imatch "^version\:\s+$($this.GetVersionArgument($_package))").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = (Invoke-Expression -Command "`$r = dpkg -s $($_package.Name) 2>&1; if (!`$?) { return `$null }; return `$r")
        return ($null -eq $result)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "apt-cache madison $($_package.Name) 2>&1"
        if (($null -eq $result) -or ($result.Length -eq 0)) {
            throw "The $($_package.Name) package was not found on apt-get"
        }

        return ($result[0] -split '\|')[1].Trim()
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        return $_package.Version
    }
}