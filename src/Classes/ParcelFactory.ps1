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

    [int] InstallProviders()
    {
        $_installed = 0

        foreach ($_name in $this.Providers.Keys)
        {
            $_provider = $this.Providers[$_name]

            if ($_provider.TestProviderInstalled()) {
                continue
            }

            Write-ParcelPackageHeader -Message "$($_provider.Name) [Provider]"

            $result = $_provider.InstallProvider()
            $result.WriteStatusMessage()
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

            'psgallery' {
                $_provider = [PSGalleryParcelProvider]::new()
            }

            'scoop' {
                $_provider = [ScoopParcelProvider]::new()
            }

            default {
                throw "Invalid package provider supplied: $($_name)"
            }
        }

        return $_provider
    }
}