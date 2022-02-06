[CmdletBinding()]
param (
    [Parameter()] [string] $StartsWith
    , [Parameter()] [string] $EndsWith
    , [Parameter()] [string] $Contains
    , [Parameter()] [string] $Exclude
    , [Parameter()] [int] $WordLength = 5
)

function Get-WordsApi($Offset = 0) {
    $Limit = 2500
    $webResult = Invoke-WebRequest -Uri "https://api.yourdictionary.com/wordfinder/v1/wordlist?special=length&order_by=alpha&limit=$Limit&offset=$Offset&word_length=$WordLength&starts=$StartsWith&contains=$($Contains[0])&ends=$EndsWith&has_definition=check&suggest_links=true&dictionary=WL"
    $jsonData = ($webResult.Content | ConvertFrom-Json).data
    $words = $jsonData._items
    $total = $jsonData._meta.total

    if (($words.Length + $Offset) -lt $total) {
        return $words + (Get-WordsApi($Offset + $words.Length))
    }

    return $words
}

$words = Get-WordsApi

if ($Contains.Length -gt 1) {
    for ($i = 1; $i -lt $Contains.Length; $i++) {
        $words = $words | Where-Object { $_ -match "[$($Contains[$i])]" }
    }
}

if ($Exclude.Length -gt 0) {
    $words = $words | Where-Object { $_ -notmatch "[$Exclude]" }
}

return $words