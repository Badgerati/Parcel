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
    [string[]] $Environment
    [ParcelOSType] $OS

    [ParcelScripts] $Scripts

    # base constructor
    ParcelPackage([hashtable]$_package)
    {
        # fail on no name
        if ([string]::IsNullOrWhiteSpace($_package.name)) {
            throw "No name supplied for $($_package.provider) package"
        }

        # set ensure to default
        if ([string]::IsNullOrWhiteSpace($_package.ensure)) {
            $_package.ensure = 'neutral'
        }

        # set environment to default
        if ([string]::IsNullOrWhiteSpace($_package.environment)) {
            $_package.environment = @('all')
        }

        # set os to default
        if ([string]::IsNullOrWhiteSpace($_package.os)) {
            $_package.os = 'all'
        }

        # if version is empty, assume latest
        if ([string]::IsNullOrWhiteSpace($_package.version)) {
            $_package.version = 'latest'
        }

        # are we using the latest version?
        if ([string]::IsNullOrWhiteSpace($_package.version) -or ($_package.version -ieq 'latest')) {
            $this.IsLatest = $true
        }

        # set the properties
        $this.Name = $_package.name
        $this.Version = $_package.version
        $this.ProviderName = $_package.provider
        $this.Source = $_package.source
        $this.Arguments = [ParcelArguments]::new($_package.args)

        $this.Ensure = [ParcelEnsureType]$_package.ensure
        $this.OS = $_package.os
        $this.Environment = @($_package.environment)
        $this.When = $_package.when

        # set the scripts
        $this.Scripts = [ParcelScripts]::new($_package.pre, $_package.post)
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
        if (($this.Environment.Length -eq 0) -or ($this.Environment.Length -eq 1 -and $this.Environment[0] -ieq 'all')) {
            return $null
        }

        $valid = ($this.Environment -icontains $_environment)
        if ($valid) {
            return $null
        }

        return [ParcelStatus]::new('Skipped', "Wrong environment [$($this.Environment -join ', ') =/= $($_environment)]")
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