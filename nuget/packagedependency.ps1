function GetDependenciesFromTargets() {
    param (
        [string] $package,
        $targets
    )

    $dependencies = @{}

    foreach ($property in $targets."$package".dependencies.psobject.properties) {
        $name = $property.Name
        $version = $property.Value.Trim("[]")
        $dependencies[$name] = $version
    
        $result = GetDependenciesFromTargets "$name/$version" $targets
        $result.Keys | ForEach-Object {$dependencies[$_] = $result[$_]}
    }

    return $dependencies
}

function GetPackageDependenciesFromProjectAssets() {
    param(
        $packageName,
        $tfm,
        $projectAssetsFile
    )

    $jobj = Get-Content $projectAssetsFile | ConvertFrom-Json
    if ($tfm -eq "net461") {
        $targets = $jobj.targets.".NETFramework,Version=v4.6.1"
    }
    else {
        throw "Not supported right now."
    }

    $packageVersion = $jobj.project.frameworks.$tfm.dependencies.$packageName.version.Trim("[, )")
    
    Write-Host "Parse dependencies of $packageName/$packageVersion"
    $dependencies = GetDependenciesFromTargets "$packageName/$packageVersion" $targets
    return $dependencies
}