class ParcelArguments
{
    [string] $Install
    [string] $Uninstall

    ParcelArguments()
    {
        $this.Install = [string]::Empty
        $this.Uninstall = [string]::Empty
    }

    ParcelArguments([string]$_script)
    {
        $this.Install = $_script
        $this.Uninstall = $_script
    }

    ParcelArguments([string]$_install, [string]$_uninstall)
    {
        $this.Install = $_install
        $this.Uninstall = $_uninstall
    }
}