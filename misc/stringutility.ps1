function ReverseString() {
    return ([regex]::Matches($token,'.','RightToLeft') | ForEach-Object {$_.value}) -join ''
}
