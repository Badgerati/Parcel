class ScoopParcelProvider : ParcelProvider
{
    ScoopParcelProvider([hashtable]$package) : base('Scoop', 'Windows', $true) {}

    [bool] TestProviderInstalled()
    {
        $cmd = Get-Command -Name 'scoop' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetProviderInstallScriptBlock()
    {
        return {
            Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh') | Out-Null
        }
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "scoop install $($_package.Name)@$($this.GetVersionArgument($_package))"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "scoop uninstall $($_package.Name) -p"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = Invoke-ParcelPowershell -Command "scoop list $($_package.Name)"
        $result = ($result -imatch "^\s*$($_package.Name)\s+$($this.GetVersionArgument($_package))")
        return ((@($result) -imatch "^\s*$($_package.Name)\s+[0-9\._]+").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = Invoke-ParcelPowershell -Command "scoop list $($_package.Name)"
        return ((@($result) -imatch "^\s*$($_package.Name)\s+[0-9\._]+").Length -eq 0)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        $result = Invoke-ParcelPowershell -Command "scoop search $($_package.Name)"

        $regex = "$($_package.Name)\s+\((?<version>[0-9\._]+)\)"
        $result = @(@($result) -imatch $regex)

        if (($result.Length -gt 0) -and ($result[0] -imatch $regex)) {
            return $Matches['version']
        }

        return [string]::Empty
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ([string]::IsNullOrWhiteSpace($_package.Version) -or ($_package.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return $_package.Version
    }

    #TODO: "source" support (buckets in this case)
    #TODO: show what latest is?
    #TODO: "args" support
}