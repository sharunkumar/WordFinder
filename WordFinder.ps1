[CmdletBinding()]
param (
    [Parameter()] [ValidatePattern("^[a-zA-Z]+$")] [string] $StartsWith
    , [Parameter()] [ValidatePattern("^[a-zA-Z]+$")] [string] $EndsWith
    , [Parameter()] [ValidatePattern("^[a-zA-Z]+$")] [Alias("Include")] [string] $Contains
    , [Parameter()] [ValidatePattern("^[a-zA-Z]+$")] [string] $Exclude
    , [Parameter()] [ValidatePattern("^[a-zA-Z][1-9]+$")] [string[]] $IndexMatch
    , [Parameter()] [ValidatePattern("^[a-zA-Z][1-9]+$")] [string[]] $IndexNotMatch
    , [Parameter()] [ValidatePattern("^[_a-zA-Z]+$")] [string[]] $TemplateString
    , [Parameter()] [ValidatePattern("^[a-zA-Z]+$")] [string[]] $Charset
    , [Parameter()] [int] $WordLength = 5
    , [Parameter()] [switch] $NoRepeats
    , [Parameter()] [switch] $Spread
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

function Get-WordsApiCached {
    if ($null -eq $Global:_WordCache) {
        $Global:_WordCache = @{}
    }

    $cacheKey = "$WordLength,$StartsWith,$($Contains[0]),$EndsWith"

    if ($null -eq $Global:_WordCache[$cacheKey]) {
        $Global:_WordCache[$cacheKey] = Get-WordsApi
    }

    return $Global:_WordCache[$cacheKey]
}

$words = Get-WordsApiCached

if ($Charset.Length -gt 0) {
    $words = $words | Where-Object {
        $_ -match "^[$Charset]+$"
    }
}

if ($Contains.Length -gt 1) {
    for ($i = 1; $i -lt $Contains.Length; $i++) {
        $words = $words | Where-Object { $_ -match "[$($Contains[$i])]" }
    }
}

if ($Exclude.Length -gt 0) {
    $words = $words | Where-Object { $_ -notmatch "[$Exclude]" }
}

if ($IndexMatch.Length -gt 0) {
    for ($i = 0; $i -lt $IndexMatch.Length; $i++) {
        $index = [int]::Parse($IndexMatch[$i][1]) - 1
        $character = $IndexMatch[$i][0]
        $words = $words | Where-Object { $_[$index] -eq $character }
    }
}

if ($IndexNotMatch.Length -gt 0) {
    for ($i = 0; $i -lt $IndexNotMatch.Length; $i++) {
        $index = [int]::Parse($IndexNotMatch[$i][1]) - 1
        $character = $IndexNotMatch[$i][0]
        $words = $words | Where-Object { $_[$index] -ne $character }
    }
}

if ($TemplateString.Length -gt 0) {
    $template = $TemplateString -replace "_","."
    $words = $words | Where-Object { $_ -match $template }
}

if ($NoRepeats) {
    $words = $words | Where-Object { ([System.Collections.Generic.HashSet[char]]$_).Count -eq $_.Length }
}

if($Spread) {
    $words | ForEach-Object { Write-Host -NoNewline "$_ " }
    Exit
}

return $words