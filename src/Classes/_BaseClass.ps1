enum ParcelOSType
{
    All = 0
    Windows = 1
    Linux = 2
    MacOS = 3
}

enum ParcelEnsureType
{
    Neutral = 0
    Present = 1
    Absent = 2
}

enum ParcelStatusType
{
    Changed = 0
    Skipped = 1
}

class ParcelScripts
{
    hidden [string] $InstallScript
    hidden [string] $UninstallScript

    ParcelScripts([string]$_install, [string]$_uninstall)
    {
        $this.InstallScript = $_install
        $this.UninstallScript = $_uninstall
    }

    [void] Install()
    {
        $this.InvokeScript($this.InstallScript) | Out-Null
    }

    [void] Uninstall()
    {
        $this.InvokeScript($this.UninstallScript) | Out-Null
    }

    hidden [void] InvokeScript([string]$_script)
    {
        # do nothing if no script
        if ([string]::IsNullOrWhiteSpace($_script)) {
            return
        }

        # if we have a script, then attempt to invoke it
        $output = [string]::Empty

        try {
            $output = Invoke-Expression -Command $_script -ErrorAction Stop
        }
        catch {
            $output | Out-Default
            throw $_.Exception
        }
    }
}

class ParcelStatus
{
    [ParcelStatusType] $Status
    [string] $Reason = [string]::Empty

    ParcelStatus([ParcelStatusType]$_status)
    {
        $this.Status = $_status
    }

    ParcelStatus([ParcelStatusType]$_status, [string]$_reason)
    {
        $this.Status = $_status
        $this.Reason = $_reason
    }

    [void] WriteStatusMessage()
    {
        switch ($this.Status) {
            'Skipped' {
                Write-Host $this.Status -ForegroundColor Green -NoNewline
            }

            'Changed' {
                Write-Host $this.Status -ForegroundColor Yellow -NoNewline
            }
        }

        if ([string]::IsNullOrWhiteSpace($this.Reason)) {
            Write-Host ([string]::Empty)
        }
        else {
            Write-Host " (reason: $($this.Reason.ToLowerInvariant()))"
        }
    }
}

class ParcelProvider
{
    [string] $Name
    [string] $Provider
    [string] $Version
    [string] $Source
    [string] $Arguments

    [ParcelEnsureType] $Ensure
    [string] $When
    [string] $Environment
    [ParcelOSType] $OS

    [ParcelOSType] $ProviderOS
    [string] $ProviderName = [string]::Empty
    [bool] $RunAsPowerShell = $false

    [ParcelScripts] $PreScripts
    [ParcelScripts] $PostScripts

    # base constructor
    ParcelProvider([hashtable]$package)
    {
        # fail on no name, or provider, or both
        if ([string]::IsNullOrWhiteSpace($package.name)) {
            throw "No name supplied for $($package.provider) package"
        }

        if ([string]::IsNullOrWhiteSpace($package.provider)) {
            throw "No provider supplied for '$($package.name)' package"
        }

        # set ensure to default
        if ([string]::IsNullOrWhiteSpace($package.ensure)) {
            $package.ensure = 'neutral'
        }

        # set environment to default
        if ([string]::IsNullOrWhiteSpace($package.environment)) {
            $package.environment = 'none'
        }

        # set os to default
        if ([string]::IsNullOrWhiteSpace($package.os)) {
            $package.os = 'all'
        }

        # if version is empty, assume latest
        if ([string]::IsNullOrWhiteSpace($package.version)) {
            $package.version = 'latest'
        }

        #TODO: remove this when latest is supported
        if ([string]::IsNullOrWhiteSpace($package.version) -or ($package.version -ieq 'latest')) {
            throw "Not supplying, or using latest version is currently unsupported"
        }

        # set the properties
        $this.Name = $package.name
        $this.Version = $package.version
        $this.Provider = $package.provider
        $this.Source = $package.source
        $this.Arguments = $package.args

        $this.Ensure = [ParcelEnsureType]$package.ensure
        $this.OS = $package.os
        $this.Environment = $package.environment
        $this.When = $package.when

        # set the scripts
        $this.PreScripts = [ParcelScripts]::new($package.pre.install, $package.pre.uninstall)
        $this.PostScripts = [ParcelScripts]::new($package.post.install, $package.post.uninstall)
    }

    # implemented base functions
    [ParcelStatus] InstallProvider()
    {
        # get the scriptblock and invoke it
        Invoke-Command -ScriptBlock ($this.GetInstallProviderScriptBlock()) -ErrorAction Stop | Out-Null

        # changed
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] TestPackage([hashtable]$_context)
    {
        # check the environment
        $status = $this.TestEnvironment($_context.environment)
        if ($null -ne $status) {
            return $status
        }

        # check the os
        $status = $this.TestOS($_context.os.type)
        if ($null -ne $status) {
            return $status
        }

        # check the when script
        $status = $this.TestWhen()
        if ($null -ne $status) {
            return $status
        }

        return $null
    }

    [ParcelStatus] TestEnvironment([string]$_environment)
    {
        if ([string]::IsNullOrWhiteSpace($_environment) -or ('none' -ieq $_environment)) {
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($this.Environment) -or ('none' -ieq $this.Environment)) {
            return $null
        }

        $valid = ($_environment -ieq $this.Environment)
        if ($valid) {
            return $null
        }

        return [ParcelStatus]::new('Skipped', "Wrong environment [$($this.Environment) =/= $($_environment)]")
    }

    [ParcelStatus] TestOS([string]$_os)
    {
        if ([string]::IsNullOrWhiteSpace($this.OS) -or ('all' -ieq $this.OS)) {
            return $null
        }

        $valid = ($_os -ieq $this.OS)
        if ($valid) {
            return $null
        }

        return [ParcelStatus]::new('Skipped', "Wrong OS [$($this.OS) =/= $($_os)]")
    }

    [ParcelStatus] TestWhen()
    {
        if ([string]::IsNullOrWhiteSpace($this.When)) {
            return $null
        }

        $result = [bool](Invoke-Command -ScriptBlock ([scriptblock]::Create($this.When)) -ErrorAction Stop)
        if ($result) {
            return $null
        }

        return [ParcelStatus]::new('Skipped', 'When evaluated to false')
    }

    [ParcelStatus] Install([hashtable]$_context)
    {
        # check if package is valid
        $status = $this.TestPackage($_context)
        if ($null -ne $status) {
            return $status
        }

        # do nothing if already installed
        if ($this.TestInstalled()) {
            return [ParcelStatus]::new('Skipped', 'Already installed')
        }

        # run any pre-install scripts
        $this.PreScripts.Install()

        # attempt to install
        $output = [string]::Empty

        try {
            $script = $this.GetInstallScript()

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
        $this.PostScripts.Install()

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [ParcelStatus] Uninstall([hashtable]$_context)
    {
        # check if package is valid
        $status = $this.TestPackage($_context)
        if ($null -ne $status) {
            return $status
        }

        # do nothing if already uninstalled
        if ($this.TestUninstalled()) {
            return [ParcelStatus]::new('Skipped', 'Already uninstalled')
        }

        # run any pre-install scripts
        $this.PreScripts.Uninstall()

        # attempt to uninstall
        $output = [string]::Empty

        try {
            $script = $this.GetUninstallScript()

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
        $this.PostScripts.Uninstall()

        # state we have changed something
        return [ParcelStatus]::new('Changed')
    }

    [string] GetHeaderMessage()
    {
        return "$($this.Name.ToUpperInvariant()) [v$($this.Version) - $($this.ProviderName)]"
    }

    [bool] TestUninstalled()
    {
        return (!$this.TestInstalled())
    }

    [bool] TestExitCode([int]$_code, [string]$_output, [string]$_action)
    {
        return ($_code -ieq 0)
    }


    # unimplemented base functions
    [bool] TestProvider()
    {
        return $true
    }

    [scriptblock] GetInstallProviderScriptBlock()
    {
        throw [System.NotImplementedException]::new()
    }

    [string] GetInstallScript()
    {
        throw [System.NotImplementedException]::new()
    }

    [string] GetUninstallScript()
    {
        throw [System.NotImplementedException]::new()
    }

    [bool] TestInstalled()
    {
        throw [System.NotImplementedException]::new()
    }
}