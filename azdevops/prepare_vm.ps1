
# Install data disks
$disks = Get-Disk | Sort Number
# 83..89 = S..Y 
$letters = 83..89 | ForEach-Object { [char]$_ } 
$count = 0
$label = "datadisk"
 
for($index = 2; $index -lt $disks.Count; $index++) {
    $driveLetter = $letters[$count].ToString()
    if ($disks[$index].partitionstyle -eq 'raw') {
        $disks[$index] | Initialize-Disk -PartitionStyle MBR -PassThru | 
            New-Partition -UseMaximumSize -DriveLetter $driveLetter | 
            Format-Volume -FileSystem NTFS -NewFileSystemLabel "$label.$count" -Confirm:$false -Force
    } else {
        $disks[$index] | Get-Partition | Set-Partition -NewDriveLetter $driveLetter
    }
    $count++
}

# Install VSTS agent work dir
[Environment]::SetEnvironmentVariable("VSTS_AGENT_INPUT_WORK", "S:\a")
[Environment]::SetEnvironmentVariable("VSTS_AGENT_INPUT_WORK", "S:\a", "Machine")

New-Item -ItemType Directory $ENV:VSTS_AGENT_INPUT_WORK
New-Item -ItemType SymbolicLink -Path "C:\a" -Target $ENV:VSTS_AGENT_INPUT_WORK

# Preinstall tools
Set-ExecutionPolicy Bypass -Scope Process -Force; `
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install git vscode -y
