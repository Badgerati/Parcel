class ChocoParcelProvider : ParcelProvider
{
    ChocoParcelProvider() : base('Chocolatey', $false, 'chocolatey') {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        $cmd = Get-Command -Name 'choco' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetProviderInstallScriptBlock([hashtable]$_context)
    {
        return {
            Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
        }
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "choco install $($_package.Name) --no-progress -y -f --allow-unofficial --allow-downgrade"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "choco uninstall $($_package.Name) --no-progress -y -f -x --allversions"
    }

    [string] GetProviderRemoveSourceScript([string]$_name)
    {
        return "choco source remove --name $($_name) -f -y"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        return "choco source add --name $($_name) --source $($_url) -f -y --no-progress --allow-unofficial"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "choco list -lo $($_package.Name) $($this.GetVersionArgument($_package))"
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\.]+").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "choco list -lo $($_package.Name)"
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\.]+").Length -eq 0)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        $result = Invoke-Expression -Command "choco search $($_package.Name) --exact $($this.GetSourceArgument($_package)) --allow-unofficial"

        $regex = "$($_package.Name)\s+(?<version>[0-9\.]+)"
        $result = @(@($result) -imatch $regex)

        if (($result.Length -gt 0) -and ($result[0] -imatch $regex)) {
            return $Matches['version']
        }

        return [string]::Empty
    }

    [bool] TestExitCode([int]$_code, [string]$_output, [string]$_action)
    {
        # valid exit codes
        if (@(0, 3010) -icontains $_code) {
            return $true
        }

        # valid outputs
        switch ($_action.ToLowerInvariant()) {
            'install' {
                return (($_output -ilike '*has been successfully installed*') -or ($_output -ilike '*has been installed*'))
            }

            'uninstall' {
                return (($_output -ilike '*has been successfully uninstalled*') -or ($_output -ilike '*Cannot uninstall a non-existent package*'))
            }

            'source' {
                return $true
            }
        }

        return $false
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ($_package.IsLatest) {
            return [string]::Empty
        }

        return "--version $($_package.Version)"
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

        return "--source $($_source)"
    }
}