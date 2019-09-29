class PSGalleryParcelProvider : ParcelProvider
{
    PSGalleryParcelProvider([hashtable]$package) : base($package)
    {
        $this.ProviderName = 'PowerShell Gallery'
        $this.ProviderOS = 'All'
    }

    [bool] TestProvider()
    {
        if ((Get-Host).Version.Major -gt '5') {
            return $true
        }

        return ($null -ne (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore))
    }

    [scriptblock] GetInstallProviderScriptBlock()
    {
        return {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        }
    }

    [string] GetInstallScript()
    {
        return "Install-Module -Name $($this.Name) -Force $($this.GetVersionArgument()) -AllowClobber -SkipPublisherCheck -ErrorAction Stop"
    }

    [string] GetUninstallScript()
    {
        return "Uninstall-Module -Name $($this.Name) -Force -AllVersions -ErrorAction Stop"
    }

    [bool] TestInstalled()
    {
        $result = (Get-Module -Name $this.Name -ListAvailable | Where-Object { $_.Version -ieq $this.Version })
        return ($result.Length -gt 0)
    }

    [string] GetVersionArgument()
    {
        if ([string]::IsNullOrWhiteSpace($this.Version) -or ($this.Version -ieq 'latest')) {
            return [string]::Empty
        }

        return "-RequiredVersion $($this.Version)"
    }

    #TODO: Source (repository)
    #TODO: get latest version!!
    #TODO: "args" support
}