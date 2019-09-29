Task 'Build' YamlDotNet, { }

Task 'YamlDotNet' {
    if (Test-Path ./src/lib/YamlDotNet) {
        Remove-Item -Path ./src/lib/YamlDotNet -Force -Recurse -ErrorAction Stop | Out-Null
    }

    if (Test-Path ./temp) {
        Remove-Item -Path ./temp -Force -Recurse -ErrorAction Stop | Out-Null
    }

    $version = '7.0.0'
    nuget install yamldotnet -source nuget.org -version $version -outputdirectory ./temp | Out-Null
    New-Item -Path ./src/lib/YamlDotNet -ItemType Directory -Force | Out-Null
    Copy-Item -Path "./temp/YamlDotNet.$($version)/lib/*" -Destination ./src/lib/YamlDotNet -Recurse -Force | Out-Null

    if (Test-Path ./temp) {
        Remove-Item -Path ./temp -Force -Recurse | Out-Null
    }

    Remove-Item -Path ./src/lib/YamlDotNet/net20 -Force -Recurse | Out-Null
    Remove-Item -Path ./src/lib/YamlDotNet/net35 -Force -Recurse | Out-Null
    Remove-Item -Path ./src/lib/YamlDotNet/net35-client -Force -Recurse | Out-Null
    Remove-Item -Path ./src/lib/YamlDotNet/netstandard1.3 -Force -Recurse | Out-Null
}