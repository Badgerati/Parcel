class ParcelFactory
{
    hidden [hashtable] $Providers
    static [ParcelFactory] $_instance

    static [ParcelFactory] Instance()
    {
        if ($null -eq [ParcelFactory]::_instance) {
            [ParcelFactory]::_instance = [ParcelFactory]::new()
        }

        return [ParcelFactory]::_instance
    }

    ParcelFactory()
    {
        $this.Providers = @{}
    }

    [ParcelProvider] GetProvider([string]$_name)
    {
        $this.AddProvider($_name)
        return $this.Providers[$_name]
    }

    [void] AddProvider([string]$_name)
    {
        $_provider = $this.Providers[$_name]
        if ($null -ne $_provider) {
            return
        }

        $_provider = $this.GetProviderInternal($_name)
        $this.Providers[$_name] = $_provider
    }

    [int] InstallProviders([hashtable]$_context, [bool]$_dryRun)
    {
        $_installed = 0

        foreach ($_name in $this.Providers.Keys)
        {
            $_provider = $this.Providers[$_name]

            # do nothing if provider is installed
            if ($_provider.TestProviderInstalled($_context)) {
                continue
            }

            # otherwise, attempt at installing it
            Write-ParcelPackageHeader -Message "$($_provider.Name) [Provider]"

            $result = $_provider.InstallProvider($_context, $_dryRun)
            $result.WriteStatusMessage($_dryRun)
            $_installed++

            Write-Host ([string]::Empty)
        }

        return $_installed
    }

    [ParcelProvider] GetProviderInternal([string]$_name)
    {
        if ([string]::IsNullOrWhiteSpace($_name)) {
            throw "Provider name in Factory cannot be empty"
        }

        $_provider = $null

        switch ($_name.ToLowerInvariant()) {
            'choco' {
                $_provider = [ChocoParcelProvider]::new()
            }

            { @('psgallery', 'ps-gallery') -icontains $_name } {
                $_provider = [PSGalleryParcelProvider]::new()
            }

            'scoop' {
                $_provider = [ScoopParcelProvider]::new()
            }

            'brew' {
                $_provider = [BrewParcelProvider]::new()
            }

            'docker' {
                $_provider = [DockerParcelProvider]::new()
            }

            { @('winfeature', 'win-feature') -icontains $_name } {
                $_provider = [WindowsFeatureParcelProvider]::new()
            }

            default {
                throw "Invalid package provider supplied: $($_name)"
            }
        }

        return $_provider
    }
}