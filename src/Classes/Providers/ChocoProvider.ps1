# using class Providers.ParcelProvider
# using class ParcelPackage

class ChocoParcelProvider : ParcelProvider
{
    ChocoParcelProvider() : base('Chocolatey', 'Windows', $false) {}

    [bool] TestProviderInstalled()
    {
        $cmd = Get-Command -Name 'choco' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetProviderInstallScriptBlock()
    {
        return {
            Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
        }
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        return "choco install $($_package.Name) --no-progress -y -f --allow-unofficial --allow-downgrade"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        return "choco uninstall $($_package.Name) --no-progress -y -f -x --allversions"
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
        }

        return $false
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ([string]::IsNullOrWhiteSpace($_package.Version) -or ($_package.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return "--version $($_package.Version)"
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        if ([string]::IsNullOrWhiteSpace($_package.Source)) {
            return [string]::Empty
        }

        return "--source $($_package.Source)"
    }

    #TODO: Source
    #TODO: show what latest is?
    #TODO: "args" support
}