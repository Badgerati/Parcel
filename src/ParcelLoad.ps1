# get the path to the libraries
$libraries = Join-Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path) 'lib'
$libraries = Join-Path $libraries 'YamlDotNet'

# load the relevant yaml lib based on the ps type
$path = [string]::Empty
$name = 'YamlDotNet.dll'

switch ($PSEdition.ToLowerInvariant()) {
    'core' {
        $path = Join-Path 'netstandard2.1' $name
    }

    default {
        $path = Join-Path 'net45' $name
    }
}

[System.Reflection.Assembly]::LoadFrom((Join-Path $libraries $path)) | Out-Null