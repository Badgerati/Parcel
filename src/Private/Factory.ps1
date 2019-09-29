function ConvertTo-ParcelProviders
{
    param(
        [Parameter()]
        [hashtable[]]
        $Packages
    )

    # do nothing if there are no packages
    if (($Packages | Measure-Object).Count -eq 0) {
        Write-Host "No packages supplied" -ForegroundColor Yellow
        return
    }

    # convert each package to a parcel provider
    $Packages | ForEach-Object {
        ConvertTo-ParcelProvider -Package $_
    }
}

function ConvertTo-ParcelProvider
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Package
    )

    if ([string]::IsNullOrEmpty($Package.provider)) {
        throw "Package provider is mandatory for $($Package.name)"
    }

    switch ($Package.provider.ToLowerInvariant()) {
        'choco' {
            return [ChocoParcelProvider]::new($Package)
        }

        'psgallery' {
            return [PSGalleryParcelProvider]::new($Package)
        }

        'scoop' {
            return [ScoopParcelProvider]::new($Package)
        }

        default {
            throw "Invalid package provider supplied: $($Package.provider)"
        }
    }
}

function Write-ParcelHeader
{
    param(
        [Parameter(ParameterSetName='Message')]
        [string]
        $Message = [string]::Empty,

        [Parameter(ParameterSetName='Package')]
        [ParcelProvider]
        $Package
    )

    if ($PSCmdlet.ParameterSetName -ieq 'package') {
        $Message = $Package.GetHeaderMessage()
    }

    $dashes = ('-' * (80 - $Message.Length))
    Write-Host "$($Message)$($dashes)>"
}

function Get-ParcelContext
{
    param(
        [Parameter()]
        [string]
        $Environment
    )

    # initial empty context
    $ctx = @{
        os = @{
            type = $null
            name = $null
            version = $null
        }
        environment = $null
        package = @{
            provider = $null
        }
    }

    # set os
    if ($PSVersionTable.PSEdition -ieq 'desktop') {
        $ctx.os.type = 'windows'
        $ctx.os.name = 'windows'
        $ctx.os.version = "$($PSVersionTable.BuildVersion)"
    }
    elseif ($IsWindows) {
        $ctx.os.type = 'windows'
        $ctx.os.name = 'windows'
        $ctx.os.version = ($PSVersionTable.OS -split '\s+')[-1]
    }
    elseif ($IsLinux) {
        $ctx.os.type = 'linux'
        $ctx.os.name = 'linux'

        if ($PSVersionTable.OS -imatch '(?<name>(ubuntu|centos|debian|fedora))') {
            $ctx.os.name = $Matches['name'].ToLowerInvariant()
        }

        if ($PSVersionTable.OS -imatch '^linux\s+[0-9\.\-]+microsoft') {
            $ctx.os.name = 'ubuntu'
        }
    }
    elseif ($IsMacOS) {
        $ctx.os.type = 'macos'
        $ctx.os.name = 'darwin'

        if ($PSVersionTable.OS -imatch '^(?<name>[a-z]+)\s+(?<version>[0-9\.]+)') {
            $ctx.os.name = $Matches['name'].ToLowerInvariant()
            $ctx.os.version = $Matches['version'].ToLowerInvariant()
        }
    }

    # set environment
    $ctx.environment = $Environment
    if ([string]::IsNullOrWhiteSpace($ctx.environment)) {
        $ctx.environment = 'none'
    }

    # return the context
    $ctx.environment = $ctx.environment.ToLowerInvariant()
    return $ctx
}

function Invoke-ParcelPackages
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Install', 'Uninstall')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ParcelProvider[]]
        $Packages,

        [Parameter()]
        [string]
        $Environment,

        [switch]
        $IgnoreEnsures
    )

    Write-Host ([string]::Empty)
    $start = [datetime]::Now

    # get the parcel context
    $parcel = Get-ParcelContext -Environment $Environment

    # map of which providers are installed, and general stats
    $providers = @{}
    $stats = @{
        Install = 0
        Uninstall = 0
        Skipped = 0
    }

    # check if we need to install any providers
    foreach ($package in $Packages) {
        if (!$providers[$package.Provider]) {
            if (($null -eq $package.TestPackage($parcel)) -and !$package.TestProvider()) {
                Write-ParcelHeader -Message "$($package.ProviderName) [Provider]"
                $result = $package.InstallProvider()
                $result.WriteStatusMessage()
                $stats.Install++
                Write-Host ([string]::Empty)
            }

            $providers[$package.Provider] = $true
        }
    }

    # attempt to install/uninstall each package
    foreach ($package in $Packages) {
        Write-ParcelHeader -Package $package

        # set parcel context for package
        $parcel.package.provider = $package.Provider
        $_action = $Action

        # skip any package with a specific ensure type
        if ($IgnoreEnsures -and (@('present', 'absent') -icontains $package.Ensure)) {
            $result = [ParcelStatus]::new('Skipped', 'Ingoring ensures on packages')
        }

        # install or uninstall?
        else {
            foreach ($i in 1..3) {
                try {
                    switch ($Action.ToLowerInvariant()) {
                        'install' {
                            if (@('neutral', 'present') -icontains $package.Ensure) {
                                $result = $package.Install($parcel)
                            }
                            else {
                                $_action = 'uninstall'
                                $result = $package.Uninstall($parcel)
                            }
                        }

                        'uninstall' {
                            if (@('neutral', 'absent') -icontains $package.Ensure) {
                                $result = $package.Uninstall($parcel)
                            }
                            else {
                                $_action = 'install'
                                $result = $package.Install($parcel)
                            }
                        }
                    }

                    # this was successful, so dont retry
                    break
                }
                catch {
                    if ($i -eq 3) {
                        throw $_.Exception
                    }

                    continue
                }
            }
        }

        # add to stats
        if ($result.Status -ieq 'Skipped') {
            $_action = 'Skipped'
        }

        $stats[$_action]++

        # write out the status
        $result.WriteStatusMessage()
        Write-Host ([string]::Empty)

        # refresh the environment and path
        Update-ParcelEnvironmentVariables
        Update-ParcelEnvironmentPath
    }

    # write out the stats
    Write-Host "(installed: $($stats.Install), uninstalled: $($stats.Uninstall), skipped: $($stats.Skipped))"

    # write out the total time
    $end = ([datetime]::Now - $start)
    Write-Host "Duration: $($end.Hours) hour(s), $($end.Minutes) minute(s) and $($end.Seconds) second(s)"
    Write-Host ([string]::Empty)
}

function Invoke-ParcelPowershell
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Command
    )

    if ($PSVersionTable.PSEdition -ieq 'Desktop') {
        return (powershell -c $Command)
    }
    else {
        return (pwsh -c $Command)
    }
}

function Get-ParcelEnvironmentVariable
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Scope
    )

    return [System.Environment]::GetEnvironmentVariable($Name, $Scope)
}

function Get-ParcelEnvironmentVariables
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Scope
    )

    return ([System.Environment]::GetEnvironmentVariables($Scope)).Keys
}

function Update-ParcelEnvironmentPath
{
    # get items in current path
    $items = @(@($env:PATH -split ';') | Select-Object -Unique)

    # add new items from paths
    @('Machine', 'User') | ForEach-Object {
        @((Get-ParcelEnvironmentVariable -Name 'PATH' -Scope $_) -split ';') | Select-Object -Unique | ForEach-Object {
            if ($items -inotcontains $_) {
                $items += $_
            }
        }
    }

    $env:PATH = ($items -join ';')
}

function Update-ParcelEnvironmentVariables
{
    foreach ($scope in @('Process', 'Machine', 'User')) {
        foreach ($var in (Get-ParcelEnvironmentVariables -Scope $scope)) {
            Set-Item "Env:$($var)" -Value (Get-ParcelEnvironmentVariable -Name $var -Scope $scope) -Force
        }
    }
}