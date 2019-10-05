class BrewParcelProvider : ParcelProvider
{
    BrewParcelProvider() : base('Brew', $false, 'brew') {}

    [bool] TestProviderInstalled()
    {
        $cmd = Get-Command -Name 'brew' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetProviderInstallScriptBlock()
    {
        return {
            Invoke-Expression 'echo | /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" > /dev/null' | Out-Null
        }
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        #TODO: any extra args?
        return "brew install $($_package.Name)"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        #TODO: any extra args?
        return "brew uninstall $($_package.Name)"
    }

    [string] GetProviderRemoveSourceScript([string]$_name)
    {
        return "choco source remove --name $($_name) -f -y"
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        #TODO:
        return "choco source add --name $($_name) --source $($_url) -f -y --no-progress --allow-unofficial"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        #TODO:
        $result = Invoke-Expression -Command "choco list -lo $($_package.Name) $($this.GetVersionArgument($_package))"
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\.]+").Length -gt 0)
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        #TODO:
        $result = Invoke-Expression -Command "choco list -lo $($_package.Name)"
        return ((@($result) -imatch "$($_package.Name)\s+[0-9\.]+").Length -eq 0)
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        #TODO:
        $result = Invoke-Expression -Command "choco search $($_package.Name) --exact $($this.GetSourceArgument($_package)) --allow-unofficial"

        $regex = "$($_package.Name)\s+(?<version>[0-9\.]+)"
        $result = @(@($result) -imatch $regex)

        if (($result.Length -gt 0) -and ($result[0] -imatch $regex)) {
            return $Matches['version']
        }

        return [string]::Empty
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        #TODO:
        if ([string]::IsNullOrWhiteSpace($_package.Version) -or ($_package.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return "--version $($_package.Version)"
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        #TODO:
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