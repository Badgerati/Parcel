class ParcelPackage
{
    [string] $Name
    [string] $ProviderName
    [string] $Source
    [ParcelArguments] $Arguments

    [string] $Version
    [bool] $IsLatest = $false

    [ParcelEnsureType] $Ensure
    [string] $When
    [string] $Environment
    [ParcelOSType] $OS

    [ParcelScripts] $Scripts

    # base constructor
    ParcelPackage([hashtable]$package)
    {
        # fail on no name
        if ([string]::IsNullOrWhiteSpace($package.name)) {
            throw "No name supplied for $($package.provider) package"
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

        # are we using the latest version?
        if ([string]::IsNullOrWhiteSpace($package.version) -or ($package.version -ieq 'latest')) {
            $this.IsLatest = $true
        }

        # set the properties
        $this.Name = $package.name
        $this.Version = $package.version
        $this.ProviderName = $package.provider
        $this.Source = $package.source
        $this.Arguments = [ParcelArguments]::new($package.args)

        $this.Ensure = [ParcelEnsureType]$package.ensure
        $this.OS = $package.os
        $this.Environment = $package.environment
        $this.When = $package.when

        # set the scripts
        $this.Scripts = [ParcelScripts]::new($package.pre, $package.post)
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
}