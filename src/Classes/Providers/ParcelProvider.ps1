class ParcelProvider
{
    [string] $Name = [string]::Empty
    [bool] $RunAsPowerShell = $false
    [string] $DefaultSource
    [ParcelArguments] $Arguments

    # base constructor
    ParcelProvider([string]$_name, [bool]$_runAsPowershell, [string]$_defaultSource)
    {
        if ([string]::IsNullOrWhiteSpace($_name)) {
            throw 'No name provided for Parcel provider'
        }

        $this.Name = $_Name
        $this.RunAsPowerShell = $_runAsPowershell
        $this.DefaultSource = $_defaultSource
        $this.Arguments = [ParcelArguments]::new($null)
    }

    # implemented base functions
    [ParcelStatus] InstallProvider([hashtable]$_context, [bool]$_dryRun)
    {
        # get the scriptblock and invoke it
        if (!$_dryRun) {
            Invoke-Command -ScriptBlock ($this.GetProviderInstallScriptBlock($_context)) -ErrorAction Stop | Out-Null
        }

        # changed
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] Install([ParcelPackage]$_package, [hashtable]$_context, [bool]$_dryRun)
    {
        # check if package is valid
        $status = $_package.TestPackage($_context)
        if ($null -ne $status) {
            return $status
        }

        # do nothing if package is already installed
        if ($this.TestPackageInstalled($_package)) {
            return [ParcelStatus]::new('Skipped', 'Already installed')
        }

        # run any pre-install scripts
        $_package.Scripts.PreInstall($_dryRun)

        # attempt to install
        $output = [string]::Empty

        try {
            # get install script - adding args, version and source
            $_script = $this.GetPackageInstallScript($_package)
            $_script += " $($_package.Arguments.Install)"
            $_script += " $($this.Arguments.Install)"

            $_version = $this.GetVersionArgument($_package)
            if (![string]::IsNullOrWhiteSpace($_version) -and !$_script.Contains($_version)) {
                $_script += " $($_version)"
            }

            $_source = $this.GetSourceArgument($_package)
            if (![string]::IsNullOrWhiteSpace($_source) -and !$_script.Contains($_source)) {
                $_script += " $($_source)"
            }

            Write-Verbose $_script

            if (!$_dryRun) {
                if ($this.RunAsPowerShell) {
                    $output = Invoke-ParcelPowershell -Command $_script
                }
                else {
                    $output = Invoke-Expression -Command $_script -ErrorAction Stop
                }

                if (!$this.TestExitCode($LASTEXITCODE, $output, 'install')) {
                    throw 'Failed to install package'
                }
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }

        # run any pre-install scripts
        $_package.Scripts.PostInstall($_dryRun)

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] Uninstall([ParcelPackage]$_package, [hashtable]$_context, [bool]$_dryRun)
    {
        # check if package is valid
        $status = $_package.TestPackage($_context)
        if ($null -ne $status) {
            return $status
        }

        # do nothing if already uninstalled
        if ($this.TestPackageUninstalled($_package)) {
            return [ParcelStatus]::new('Skipped', 'Already uninstalled')
        }

        # run any pre-install scripts
        $_package.Scripts.PreUninstall($_dryRun)

        # attempt to uninstall
        $output = [string]::Empty

        try {
            # get uninstall script - adding args
            $_script = $this.GetPackageUninstallScript($_package)
            $_script += " $($_package.Arguments.Uninstall)"
            $_script += " $($this.Arguments.Uninstall)"

            Write-Verbose $_script

            if (!$_dryRun) {
                if ($this.RunAsPowerShell) {
                    $output = Invoke-ParcelPowershell -Command $_script
                }
                else {
                    $output = Invoke-Expression -Command $_script -ErrorAction Stop
                }

                if (!$this.TestExitCode($LASTEXITCODE, $output, 'uninstall')) {
                    throw 'Failed to uninstall package'
                }
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }

        # run any pre-install scripts
        $_package.Scripts.PostUninstall($_dryRun)

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [void] SetPackageLatestVersion([ParcelPackage]$_package)
    {
        if (!$_package.IsLatest) {
            return
        }

        $_package.Version = $this.GetPackageLatestVersion($_package)
    }

    [string] GetPackageHeaderMessage([ParcelPackage]$_package)
    {
        $_latestFlag = [string]::Empty
        if ($_package.IsLatest) {
            $_latestFlag = ' <latest>'
        }

        return "$($_package.Name.ToUpperInvariant()) [v$($_package.Version)$($_latestFlag) - $($this.Name)]"
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        return (!$this.TestPackageInstalled($_package))
    }

    [bool] TestExitCode([int]$_code, [string]$_output, [string]$_action)
    {
        return ($_code -ieq 0)
    }

    [void] SetCustomSources([hashtable]$_sources, [bool]$_dryRun)
    {
        # do nothing if there are no sources
        if ($null -eq $_sources) {
            return
        }

        # ensure we don't haave more than 1 source as default
        if (($_sources | Where-Object { $_.default } | Measure-Object).Count -gt 1) {
            throw "More than one custom source has been flagged as default for the $($this.Name) provider"
        }

        Write-ParcelHeader -Message "SOURCES [$($this.Name)]"

        # attempt to add each source, failing if there is no name/url
        foreach ($_source in $_sources) {
            Write-Host "- $($_source.name): $($_source.url)"
            $this.RemoveSource($_source, $_dryRun)
            $this.AddSource($_source, $_dryRun)
        }

        Write-Host ([string]::Empty)
    }

    [void] AddSource([hashtable]$_source, [bool]$_dryRun)
    {
        if ([string]::IsNullOrWhiteSpace($_source.name)) {
            throw "A $($this.Name) source has no name defined"
        }

        if ([string]::IsNullOrWhiteSpace($_source.url)) {
            throw "A $($this.Name) source ($($_source.name)) has no URL defined"
        }

        $output = [string]::Empty

        try {
            # get add source script
            $_script = $this.GetProviderAddSourceScript($_source.name, $_source.url)
            Write-Verbose $_script

            if (!$_dryRun) {
                if ($this.RunAsPowerShell) {
                    $output = Invoke-ParcelPowershell -Command $_script
                }
                else {
                    $output = Invoke-Expression -Command $_script -ErrorAction Stop
                }

                if (!$this.TestExitCode($LASTEXITCODE, $output, 'source')) {
                    throw 'Failed to add source'
                }
            }

            if ($_source.default) {
                $this.DefaultSource = $_source.name
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }
    }

    [void] RemoveSource([hashtable]$_source, [bool]$_dryRun)
    {
        if ([string]::IsNullOrWhiteSpace($_source.name)) {
            throw "A $($this.Name) source has no name defined"
        }

        $output = [string]::Empty

        try {
            # get remove source script
            $_script = $this.GetProviderRemoveSourceScript($_source.name)
            Write-Verbose $_script

            if (!$_dryRun) {
                if ($this.RunAsPowerShell) {
                    $output = Invoke-ParcelPowershell -Command $_script
                }
                else {
                    $output = Invoke-Expression -Command $_script -ErrorAction Stop
                }

                if (!$this.TestExitCode($LASTEXITCODE, $output, 'source')) {
                    throw 'Failed to remove source'
                }
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }
    }

    [void] SetArguments([object]$_args)
    {
        $this.Arguments = [ParcelArguments]::new($_args)
    }


    # unimplemented base functions
    [bool] TestProviderInstalled()
    {
        return $true
    }

    [string] GetPackageLatestVersion([ParcelPackage]$_package)
    {
        return [string]::Empty
    }

    [string] GetVersionArgument([ParcelPackage]$_package)
    {
        return [string]::Empty
    }

    [string] GetSourceArgument([ParcelPackage]$_package)
    {
        return [string]::Empty
    }

    [scriptblock] GetProviderInstallScriptBlock([hashtable]$_context)
    {
        throw [System.NotImplementedException]::new("GetProviderInstallScriptBlock ($($this.Name))")
    }

    [string] GetPackageInstallScript([ParcelPackage]$_package)
    {
        throw [System.NotImplementedException]::new("GetPackageInstallScript ($($this.Name))")
    }

    [string] GetPackageUninstallScript([ParcelPackage]$_package)
    {
        throw [System.NotImplementedException]::new("GetPackageUninstallScript ($($this.Name))")
    }

    [bool] TestPackageInstalled([ParcelPackage]$_package)
    {
        throw [System.NotImplementedException]::new("TestPackageInstalled ($($this.Name))")
    }

    [string] GetProviderAddSourceScript([string]$_name, [string]$_url)
    {
        throw [System.NotImplementedException]::new("GetProviderAddSourceScript ($($this.Name))")
    }

    [string] GetProviderRemoveSourceScript([string]$_name, [string]$_url)
    {
        throw [System.NotImplementedException]::new("GetProviderRemoveSourceScript ($($this.Name))")
    }
}