class ParcelScripts
{
    hidden [string] $PreInstallScript
    hidden [string] $PreUninstallScript

    hidden [string] $PostInstallScript
    hidden [string] $PostUninstallScript

    ParcelScripts([object]$_pre, [object]$_post)
    {
        # pre scripts
        if ($_pre -is [string]) {
            $this.PreInstallScript = $_pre
            $this.PreUninstallScript = $_pre
        }
        else {
            $this.PreInstallScript = $_pre.install
            $this.PreUninstallScript = $_pre.uninstall
        }

        # post scripts
        if ($_post -is [string]) {
            $this.PostInstallScript = $_post
            $this.PostUninstallScript = $_post
        }
        else {
            $this.PostInstallScript = $_post.install
            $this.PostUninstallScript = $_post.uninstall
        }
    }

    [void] PreInstall()
    {
        $this.InvokeScript($this.PreInstallScript) | Out-Null
    }

    [void] PostInstall()
    {
        $this.InvokeScript($this.PostInstallScript) | Out-Null
    }

    [void] PreUninstall()
    {
        $this.InvokeScript($this.PreUninstallScript) | Out-Null
    }

    [void] PostUninstall()
    {
        $this.InvokeScript($this.PostUninstallScript) | Out-Null
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