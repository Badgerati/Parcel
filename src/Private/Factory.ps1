function ConvertTo-ParcelScripts
{
    param(
        [Parameter()]
        [hashtable[]]
        $Scripts
    )

    return [ParcelScripts]::new($Scripts.pre, $Scripts.post)
}

function ConvertTo-ParcelPackages
{
    param(
        [Parameter()]
        [hashtable[]]
        $Packages,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Context
    )

    # do nothing if there are no packages
    if (($Packages | Measure-Object).Count -eq 0) {
        Write-Host "No packages supplied" -ForegroundColor Yellow
        return
    }

    # convert each package to a parcel provider
    $Packages | ForEach-Object {
        ConvertTo-ParcelPackage -Package $_ -Context $Context
    }
}

function ConvertTo-ParcelPackage
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Package,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Context
    )

    if ([string]::IsNullOrEmpty($Package.provider)) {
        throw "Package provider is mandatory for $($Package.name)"
    }

    $_package = [ParcelPackage]::new($Package)

    if ($null -eq $_package.TestPackage($Context)) {
        [ParcelFactory]::Instance().AddProvider($_package.ProviderName)
    }

    return $_package
}

function Write-ParcelPackageHeader
{
    param(
        [Parameter(ParameterSetName='Message')]
        [string]
        $Message = [string]::Empty,

        [Parameter(ParameterSetName='Package')]
        [ParcelPackage]
        $Package,

        [Parameter(ParameterSetName='Package')]
        [ParcelProvider]
        $Provider
    )

    if ($PSCmdlet.ParameterSetName -ieq 'package') {
        $Message = $Provider.GetPackageHeaderMessage($Package)
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
        [ParcelPackage[]]
        $Packages,

        [Parameter(Mandatory=$true)]
        [ParcelScripts]
        $Scripts,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Context,

        [switch]
        $IgnoreEnsures,

        [switch]
        $WhatIf
    )

    Write-Host ([string]::Empty)
    $start = [datetime]::Now

    # stats of what's installed etc
    $stats = @{
        Install = 0
        Uninstall = 0
        Skipped = 0
    }

    # check if we need to install any providers
    $stats.Install += [ParcelFactory]::Instance().InstallProviders()

    # invoke any global pre install/uninstall
    Invoke-ParcelGlobalScript -Action $Action -Stage Pre -WhatIf:$WhatIf

    # attempt to install/uninstall each package
    foreach ($package in $Packages) {
        # get the provider
        $provider = [ParcelFactory]::Instance().GetProvider($package.ProviderName)

        # update the package's version with latest if required
        if ($package.IsLatest) {
            $provider.SetPackageLatestVersion($package)
        }

        # write out the strap line
        Write-ParcelPackageHeader -Package $package -Provider $provider

        # set parcel context for package
        $Context.package.provider = $package.ProviderName
        $_action = $Action

        # skip any package with a specific ensure type
        if ($IgnoreEnsures -and (@('present', 'absent') -icontains $package.Ensure)) {
            $result = [ParcelStatus]::new('Skipped', 'Ingoring ensures on packages')
        }

        # install or uninstall?
        else {
            # loop and retry to action the package
            foreach ($i in 1..3) {
                try {
                    switch ($Action.ToLowerInvariant()) {
                        'install' {
                            if (@('neutral', 'present') -icontains $package.Ensure) {
                                $result = $provider.Install($package, $Context, $WhatIf)
                            }
                            else {
                                $_action = 'uninstall'
                                $result = $provider.Uninstall($package, $Context, $WhatIf)
                            }
                        }

                        'uninstall' {
                            if (@('neutral', 'absent') -icontains $package.Ensure) {
                                $result = $provider.Uninstall($package, $Context, $WhatIf)
                            }
                            else {
                                $_action = 'install'
                                $result = $provider.Install($package, $Context, $WhatIf)
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
        $result.WriteStatusMessage($WhatIf)
        Write-Host ([string]::Empty)

        # refresh the environment and path
        Update-ParcelEnvironmentVariables -WhatIf:$WhatIf
        Update-ParcelEnvironmentPath -WhatIf:$WhatIf
    }

    # invoke any global post install/uninstall
    Invoke-ParcelGlobalScript -Action $Action -Stage Post -WhatIf:$WhatIf

    # write out the stats
    if ($WhatIf) {
        Write-Host '[WhatIf]: ' -ForegroundColor Cyan -NoNewline
    }

    Write-Host "(installed: $($stats.Install), uninstalled: $($stats.Uninstall), skipped: $($stats.Skipped))"

    # write out the total time
    $end = ([datetime]::Now - $start)
    Write-Host "Duration: $($end.Hours) hour(s), $($end.Minutes) minute(s) and $($end.Seconds) second(s)"
    Write-Host ([string]::Empty)
}

function Invoke-ParcelGlobalScript
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Install', 'Uninstall')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Pre', 'Post')]
        [string]
        $Stage,

        [switch]
        $WhatIf
    )

    if ($WhatIf) {
        return
    }

    switch ($Action.ToLowerInvariant()) {
        'install' {
            if ($Stage -ieq 'pre') {
                $Scripts.PreInstall($WhatIf)
            }
            else {
                $Scripts.PostInstall($WhatIf)
            }
        }

        'uninstall' {
            if ($Stage -ieq 'pre') {
                $Scripts.PreUninstall($WhatIf)
            }
            else {
                $Scripts.PostUninstall($WhatIf)
            }
        }
    }
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
    param(
        [switch]
        $WhatIf
    )

    if ($WhatIf) {
        return
    }

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
    param(
        [switch]
        $WhatIf
    )

    if ($WhatIf) {
        return
    }

    foreach ($scope in @('Process', 'Machine', 'User')) {
        foreach ($var in (Get-ParcelEnvironmentVariables -Scope $scope)) {
            Set-Item "Env:$($var)" -Value (Get-ParcelEnvironmentVariable -Name $var -Scope $scope) -Force
        }
    }
}

function Test-ParcelAdminUser
{
    # check the current platform, if it's unix then return true
    if ($PSVersionTable.Platform -ieq 'unix') {
        return $true
    }

    try {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        if ($null -eq $principal) {
            return $false
        }

        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch [exception] {
        Write-Host 'Error checking user administrator privileges' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}