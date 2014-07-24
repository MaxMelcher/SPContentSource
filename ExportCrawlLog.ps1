<# 
   List Sharepoint 2013 Crawl Log
   Max Melcher (@maxmelcher), 2014
   http://melcher.it
   Use on your own risk

   This script lists SharePoint 2013 Crawl Log results in a grouped way
#>

Param(
  [string]$SearchServiceApplicationName,
  [Parameter(Position=1,Mandatory=$true)]
  [string]$ContentSourceName,
  [Parameter(Position=2)]
        [ValidateSet('Success','Warning','Error', 'Deleted', 'Everything')]
        [System.String]$Level,
        [int]$Threshold
)

Add-PSSnapin microsoft.sharepoint.powershell -ea 0


#get the search service application
if ($SearchServiceApplicationName)
{
    $ssa = Get-SPEnterpriseSearchServiceApplication | Where-Object {$_.Name -eq $SearchServiceApplicationName} 
}
else
{
    $ssa = Get-SPEnterpriseSearchServiceApplication
}


if (!$ssa)
{
    throw "No Search Service Application found"
}
else
{
    Write-Host "Search Service Application: "$ssa.Name
}

#get the ID of the content source
$cs = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $ssa | ? { $_.Name -eq $ContentSourceName}

if (!$cs)
{
    throw "No Content Source found with the specified name"
}
else
{
    Write-Host "Content Source: "$cs.Name
}

$log = New-Object Microsoft.Office.Server.Search.Administration.CrawlLog $ssa

if ($Level -eq "Success")
{
    $lvl = 0
}
elseif ($Level -eq "Warning")
{
    $lvl = 1
}
elseif ($Level -eq "Error")
{
    $lvl = 2
}
elseif ($Level -eq "Deleted")
{
    $lvl = 3
}
else
{
    $Level = "Everything"
    $lvl = -1
}

if ($Threshold -eq 0)
{
    $Threshold = 100000
}

Write-Host "Level: "$Level
Write-Host "Threshold: " $Threshold

$dt = $log.GetCrawledUrls($false, $Threshold, $null, $false, $cs.Id, $lvl, -1, [System.DateTime]::MinValue, [System.DateTime]::MaxValue)
$count = $dt.Rows.Count

if ($count -eq $Threshold)
{
    write-host -ForegroundColor Yellow "The returned count equals the threshold - there are probably more messages! Increase the threshold parameter to get more results"
}

#group by the id
$group = $dt | Group-Object "ErrorID"

#Do some reflection magic - thanks to Mikael Svenson!
$BindingFlags= [Reflection.BindingFlags] "NonPublic,Instance"
 
#Load method based on name
$PrivateMethod = $log.GetType().GetMethod("GetAllKnownErrors",$bindingFlags)
 
#Invoke
$errors = $PrivateMethod.Invoke($log, $null)

$codes = @{}
foreach ($err in $errors.GetEnumerator())
{
    $e = $err.Value
    $codes.Add($e.Id, $e.Message)
}


$msg = @()
foreach ($g in $group)
{
    $name = [int]::Parse($g.Name)
    $count = $g.Count
    $text = $codes[$name]

    $entry = @{}
    $entry.Count = $count
    $entry.Text = $text

    $obj = New-Object PSObject -Property $entry
    $msg += $obj
}

Write-Host ""
Write-Host "Result:"
$msg | Format-Table -AutoSize