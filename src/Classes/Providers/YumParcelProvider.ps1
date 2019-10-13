class YumParcelProvider : ParcelProvider
{
    YumParcelProvider() : base('Yum', $false, [string]::Empty) {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        # fail if yum isn't available
        if ($null -eq (Get-Command -Name 'yum' -ErrorAction Ignore)) {
            throw 'The provider yum is not installed'
        }

        return $true
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "sudo yum install -y -q $($_package.Name)-$($this.GetVersionArgument($_package)) 2>&1"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "sudo yum remove -y $($_package.Name) 2>&1"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "yum list installed 2>&1"
        return ($null -ne ($result | Select-String -Pattern "^$($_package.Name)\.[\w_\d]+\s+$($this.GetVersionArgument($_package))"))
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "yum list installed 2>&1"
        return ($null -eq ($result | Select-String -Pattern "^$($_package.Name)\.[\w_\d]+\s+"))
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "yum info $($_package.Name) 2>&1"
        if (!$?) {
            throw "The $($_package.Name) package was not found on yum"
        }

        return (($result | Select-String -Pattern 'version\s+\:\s+.+?')[0] -split '\:')[-1].Trim()
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        return $_package.Version
    }
}