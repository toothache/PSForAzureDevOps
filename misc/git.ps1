function CleanBranches() {
    param(
        [int] $recentCommitNumber = 5
    )

    git branch | ForEach-Object { $_.trim('* ') } | ForEach-Object {
        Write-Host "You're about to delete $_."
        Write-Host ""
        git log $_ --oneline -n $recentCommitNumber
        Write-Host ""
        $confirm = Read-Host "Confirm? Yes/No"
        if ($confirm.ToLower() -eq 'yes') {
            git branch -D $_
        } else {
            Write-Host "Skipping"
        }
    }
}

CleanBranches