class ChocoParcelProvider : ParcelProvider
{
    ChocoParcelProvider([hashtable]$package) : base($package)
    {
        $this.ProviderName = 'Chocolatey'
        $this.ProviderOS = 'Windows'
    }

    [bool] TestProvider()
    {
        $cmd = Get-Command -Name 'choco' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetInstallProviderScriptBlock()
    {
        return {
            Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
        }
    }

    [string] GetInstallScript()
    {
        return "choco install $($this.Name) $($this.GetVersionArgument()) --no-progress -y -f --allow-unofficial --allow-downgrade"
    }

    [string] GetUninstallScript()
    {
        return "choco uninstall $($this.Name) --no-progress -y -f -x --allversions"
    }

    [bool] TestInstalled()
    {
        $result = Invoke-Expression -Command "choco list -lo $($this.Name) $($this.GetVersionArgument())"
        return ((@($result) -imatch "$($this.Name)\s+[0-9\.]+").Length -gt 0)
    }

    [bool] TestUninstalled()
    {
        $result = Invoke-Expression -Command "choco list -lo $($this.Name)"
        return ((@($result) -imatch "$($this.Name)\s+[0-9\.]+").Length -eq 0)
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

    [string] GetVersionArgument()
    {
        if ([string]::IsNullOrWhiteSpace($this.Version) -or ($this.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return "--version $($this.Version)"
    }

    #TODO: Source
    #TODO: show what latest is?
    #TODO: "args" support
}