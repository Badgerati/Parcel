class ParcelProvider
{
    [ParcelOSType] $OS
    [string] $Name = [string]::Empty
    [bool] $RunAsPowerShell = $false

    # base constructor
    ParcelProvider([string]$_name, [ParcelOSType]$_os, [bool]$_runAsPowershell)
    {
        if ([string]::IsNullOrWhiteSpace($_name)) {
            throw 'No name provided for Parcel provider'
        }

        $this.Name = $_Name
        $this.OS = $_os
        $this.RunAsPowerShell = $_runAsPowershell
    }

    # implemented base functions
    [ParcelStatus] InstallProvider()
    {
        # get the scriptblock and invoke it
        Invoke-Command -ScriptBlock ($this.GetInstallProviderScriptBlock()) -ErrorAction Stop | Out-Null

        # changed
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] Install([ParcelPackage]$_package, [hashtable]$_context)
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
        $_package.PreScripts.Install()

        # attempt to install
        $output = [string]::Empty

        try {
            $script = $this.GetPackageInstallScript($_package)
            $script += " $($_package.Arguments.Install)"

            Write-Verbose $script

            if ($this.RunAsPowerShell) {
                $script += '; if (!$? -or ($LASTEXITCODE -ne 0)) { throw }'
                $output = Invoke-ParcelPowershell -Command $script
            }
            else {
                $output = Invoke-Expression -Command $script -ErrorAction Stop
            }

            if (!$this.TestExitCode($LASTEXITCODE, $output, 'install')) {
                throw 'Failed to install package'
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }

        # run any pre-install scripts
        $_package.PostScripts.Install()

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] Uninstall([ParcelPackage]$_package, [hashtable]$_context)
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
        $_package.PreScripts.Uninstall()

        # attempt to uninstall
        $output = [string]::Empty

        try {
            $script = $this.GetPackageUninstallScript($_package)
            $script += " $($_package.Arguments.Uninstall)"

            Write-Verbose $script

            if ($this.RunAsPowerShell) {
                $script += '; if (!$? -or ($LASTEXITCODE -ne 0)) { throw }'
                $output = Invoke-ParcelPowershell -Command $script
            }
            else {
                $output = Invoke-Expression -Command $script -ErrorAction Stop
            }

            if (!$this.TestExitCode($LASTEXITCODE, $output, 'uninstall')) {
                throw 'Failed to uninstall package'
            }
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }

        # run any pre-install scripts
        $_package.PostScripts.Uninstall()

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [string] GetPackageHeaderMessage([ParcelPackage]$_package)
    {
        return "$($_package.Name.ToUpperInvariant()) [v$($_package.Version) - $($this.Name)]"
    }

    [bool] TestPackageUninstalled([ParcelPackage]$_package)
    {
        return (!$this.TestInstalled())
    }

    [bool] TestExitCode([int]$_code, [string]$_output, [string]$_action)
    {
        return ($_code -ieq 0)
    }


    # unimplemented base functions
    [bool] TestProviderInstalled()
    {
        return $true
    }

    [scriptblock] GetProviderInstallScriptBlock() { throw [System.NotImplementedException]::new() }

    [string] GetPackageInstallScript([ParcelPackage]$_package) { throw [System.NotImplementedException]::new() }

    [string] GetPackageUninstallScript([ParcelPackage]$_package) { throw [System.NotImplementedException]::new() }

    [bool] TestPackageInstalled([ParcelPackage]$_package) { throw [System.NotImplementedException]::new() }
}