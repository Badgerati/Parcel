function ConvertFrom-ParcelYaml
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    $value = Get-Content -Path $Path -Raw

    try {
        $reader = [System.IO.StringReader]::new($value)
        $parser = New-Object YamlDotNet.Core.Parser -ArgumentList $reader

        $yaml = New-Object YamlDotNet.RepresentationModel.YamlStream
        $yaml.Load($parser)
    }
    finally {
        if ($null -ne $reader) {
            $reader.Close()
        }
    }

    $documents = @()
    foreach ($doc in $yaml) {
        $documents += (ConvertTo-ParcelPSObject -Document $doc.RootNode)
    }

    return $documents
}

function ConvertTo-ParcelPSObject
{
    param(
        [Parameter(Mandatory=$true)]
        $Document
    )

    if ($Document -is [YamlDotNet.RepresentationModel.YamlMappingNode]) {
        return ConvertTo-ParcelYamlToHashtable -Item $Document
    }
    elseif ($Document -is [YamlDotNet.RepresentationModel.YamlSequenceNode]) {
        return Convert-ParcelYamlToArray -Item $Document
    }
    elseif ($Document -is [YamlDotNet.RepresentationModel.YamlScalarNode]) {
        return Convert-ParcelYamlToValue -Item $Document
    }
}

function ConvertTo-ParcelYamlToHashtable
{
    param(
        [Parameter(Mandatory=$true)]
        [YamlDotNet.RepresentationModel.YamlMappingNode]
        $Item
    )

    $struct = @{}

    foreach ($key in $Item.Children.Keys) {
        $struct[$key.Value] = ConvertTo-ParcelPSObject $Item.Children[$key]
    }

    return $struct
}

function Convert-ParcelYamlToArray
{
    param(
        [Parameter(Mandatory=$true)]
        [YamlDotNet.RepresentationModel.YamlSequenceNode]
        $Item
    )

    $array = @()

    foreach ($child in $Item.Children) {
        $array += ConvertTo-ParcelPSObject $child
    }

    return $array
}

function Convert-ParcelYamlToValue
{
    param(
        [Parameter(Mandatory=$true)]
        [YamlDotNet.RepresentationModel.YamlScalarNode]
        $Item
    )

    return [string]$Item.Value
}