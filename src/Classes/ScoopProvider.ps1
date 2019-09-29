class ScoopParcelProvider : ParcelProvider
{
    ScoopParcelProvider([hashtable]$package) : base($package)
    {
        $this.ProviderName = 'Scoop'
        $this.ProviderOS = 'Windows'
        $this.RunAsPowerShell = $true
    }

    [bool] TestProvider()
    {
        $cmd = Get-Command -Name 'scoop' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    [scriptblock] GetInstallProviderScriptBlock()
    {
        return {
            Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh') | Out-Null
        }
    }

    [string] GetInstallScript()
    {
        return "scoop install $($this.Name)$($this.GetVersionArgument($true))"
    }

    [string] GetUninstallScript()
    {
        return "scoop uninstall $($this.Name) -p"
    }

    [bool] TestInstalled()
    {
        $result = Invoke-ParcelPowershell -Command "scoop list $($this.Name)"
        $result = ($result -imatch "^\s*$($this.Name)\s+$($this.GetVersionArgument($false))")
        return ((@($result) -imatch "^\s*$($this.Name)\s+[0-9\.]+").Length -gt 0)
    }

    [bool] TestUninstalled()
    {
        $result = Invoke-ParcelPowershell -Command "scoop list $($this.Name)"
        return ((@($result) -imatch "^\s*$($this.Name)\s+[0-9\.]+").Length -eq 0)
    }

    [string] GetVersionArgument([bool]$_withAt)
    {
        if ([string]::IsNullOrWhiteSpace($this.Version) -or ($this.Version -ieq 'latest')) {
            return [string]::Empty
        }

        $_version = $this.Version
        if ($_withAt) {
            $_version = "@$($_version)"
        }

        return $_version
    }

    #TODO: "source" support (buckets in this case)
    #TODO: show what latest is?
    #TODO: "args" support
}