$apiVersion = "5.0"

function CreateHTTPHeadersWithOAuth() {
    param(
        [string] $token
    )

    return @{Authorization = ("Bearer {0}" -f $token)}
}

function CreateHTTPHeadersWithPAT() {
    param(
        [string] $token
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $token)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
}

function GetGitFile() {
    param(
        $projectUrl,
        $headers,
        $filePath,
        $branch = "master"
    )

    $filename = Split-Path $filePath -leaf
    Write-Host "Sending a REST call to get latest $filename content"

    $filePath = $filePath.replace("\", "%2F")
    $branch = $branch.replace("\", "%2F")
    $itemUrl = "$projectUrl/items?api-version=$apiVersion&versionType=branch&Version=$branch"
    $fileUrl = "$itemUrl&path=$filePath"

    return Invoke-RestMethod -Headers $headers -Uri $fileUrl
}

function DownloadGitBinaryFile() {
    param(
        $projectUrl,
        $headers,
        $filePath,
        $branch = "master"
    )

    $filename = Split-Path $filePath -leaf
    Write-Host "Sending a REST call to get latest $filename content"

    $filePath = $filePath.replace("\", "%2F")
    $branch = $branch.replace("\", "%2F")
    $itemUrl = "$projectUrl/items?api-version=$apiVersion&versionType=branch&Version=$branch"
    $fileUrl = "$itemUrl&path=$filePath&resolveLfs=true&%24format=octetStream"
    Invoke-WebRequest -OutFile $filename -Method GET -Headers $headers -Uri $fileUrl
}

function DownloadGitFile() {
    param(
        $projectUrl,
        $headers,
        $filePath,
        $branch = "master"
    )

    $filename = Split-Path $filePath -leaf
    $result = GetGitFile $projectUrl $headers $filePath $branch

    if ($result.GetType().Name -eq "XmlDocument") {
        $result = $result.OuterXml
    }

    $result | Set-Content $filename
}

function CreateEmptyCommit() {
    param(
        $comment
    )
    return @{
        "comment" = $comment
        "changes" = @()
    }
}

function AddChangeToCommit() {
    param(
        $commit,
        $path,
        $content
    )

    $commit["changes"] += @{
        "changeType" = "edit"
        "item" = @{
            "path" = $path.replace("\", "/")
        }
        "newContent" = @{
            "content" = $content
            "contentType" = "rawtext"
        }
    }

    return $commit
}

function GetBranchObjectId() {
    param(
        $projectUrl,
        $headers,
        $branch = "master"
    )

    $masterRefUrl = "$projectUrl/refs?api-version=$apiVersion&filter=heads%2Fmaster"
    $masterRefResult = Invoke-RestMethod -Method GET -Headers $headers -Uri $masterRefUrl 
    $masterObjectId = $masterRefResult.value[0].objectId
    return $masterObjectId
}

function CreateNewBranch() {
    param(
        $projectUrl,
        $headers,
        $name,
        $oldObjectId,
        $comment,
        $commit
    )

    $headers.Add("Content-Type", "application/json")

    $newBranchRefName = "refs/heads/$name"
    # Json for creating a new branch
    $newBranch = @{
        "refUpdates" = @(@{
            "name" = $newBranchRefName
            "oldObjectId" = $oldObjectId
        })

        "commits" = @($commit)
    }

    $newBranchJson = ($newBranch | ConvertTo-Json -Depth 5)

    Write-Output "Sending a REST call to create a new branch $name with updated contents."

    # REST call to create a new branch
    $pushUrl = "$projectUrl/pushes?api-version=$apiVersion&versionType=branch&Version=master"
    $newBranchResponse = Invoke-RestMethod -Method POST -Headers $headers -Body $newBranchJson -Uri $pushUrl

    Write-Output "New branch '$name' created."
}

function CreatePullRequest() {
    param(
        $srcBranch,
        $destBranch,
        $title,
        $description
    )

    return @{
        "sourceRefName" = "refs/heads/$srcBranch"
        "targetRefName" = "refs/heads/$destBranch"
        "title"         = $title
        "description"   = $description
    }
}

function SubmitPullRequest() {
    param(
        $projectUrl,
        $headers,
        $pullrequest,
        $autocomplete = $false
    )

    $headers.Add("Content-Type", "application/json")

    # Create a Pull Request
    $pullRequestUrl = "$projectUrl/pullRequests?api-version=$apiVersion"

    $pullRequestJson = ($pullRequest | ConvertTo-Json -Depth 5)

    Write-Output "Sending a REST call to create a new pull request."

    # REST call to create a Pull Request
    $pullRequestResult = Invoke-RestMethod -Method POST -Headers $headers -Body $pullRequestJson -Uri $pullRequestUrl;
    $pullRequestId = $pullRequestResult.pullRequestId

    Write-Output "Pull request created. Pull Request Id: $pullRequestId"

    # Set PR to auto-complete
    if ($autocomplete) {
        $setAutoComplete = @{
            "autoCompleteSetBy" = @{
                "id" = $pullRequestResult.createdBy.id
            }
            "completionOptions" = @{
                "mergeCommitMessage" = $pullRequestResult.title
                "deleteSourceBranch" = $True
                "squashMerge"        = $True
                "bypassPolicy"       = $False
            }
        }

        $setAutoCompleteJson = ($setAutoComplete | ConvertTo-Json -Depth 5)

        Write-Output "Sending a REST call to set auto-complete on the newly created pull request"
    
        # REST call to set auto-complete on Pull Request
        $pullRequestUpdateUrl = ($projectUrl + '/pullRequests/' + $pullRequestId + '?api-version=2.0-preview')
    
        $setAutoCompleteResult = Invoke-RestMethod -Method PATCH -Headers $headers -Body $setAutoCompleteJson -Uri $pullRequestUpdateUrl
    
        Write-Output "Pull request set to auto-complete"
    }
}