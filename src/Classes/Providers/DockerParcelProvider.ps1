class DockerParcelProvider : ParcelProvider
{
    DockerParcelProvider() : base('Docker', $false, 'docker') {}

    [bool] TestProviderInstalled([hashtable]$_context)
    {
        $cmd = Get-Command -Name 'docker' -ErrorAction Ignore
        return ($null -ne $cmd)
    }

    #TODO: come back here when we can have "GetProviderInstallPackages"
    #       which can return a number of packages to install.
    #       this will allow us to install more complicated packages, and see what is being installed.
    #       also can add a flag on providers of "install: false", which will disable self-install/check

    [string] GetPackageInstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "docker pull $($_package.Name):$($this.GetVersionArgument($_package))"
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package, [hashtable]$_context)
    {
        return "docker rmi --force $($_package.Name)"
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        # always pull down the latest
        if ($_package.IsLatest) {
            return $false
        }

        # get current images
        return ($null -ne $this.FindDockerImages($_package))
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        return ($null -eq $this.FindDockerImages($_package))
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        return 'latest'
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        if ($_package.IsLatest) {
            return 'latest'
        }

        return $_package.Version
    }

    [object] FindDockerImages([ParcelPackage]$_package)
    {
        $_images = Invoke-Expression -Command "docker images --format '{{json .}}'" -ErrorAction Stop
        return ($_images | ConvertFrom-Json) | Where-Object { ($_.Repository -ieq $_package.Name) -and ($_.Tag -ieq $_package.Version) }
    }
}