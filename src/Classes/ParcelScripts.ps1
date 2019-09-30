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