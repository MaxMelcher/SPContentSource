<# 
   Create Sharepoint 2013 Content Sources
   Max Melcher (@maxmelcher), 2014
   http://melcher.it
   Use on your own risk

   This script creates or updates SharePoint 2013 Search Content Sources and their schedules
#>



#get the config xml file
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
[xml]$config = Get-Content $scriptPath\ContentSource.xml

#settings
$SearchServiceApplicationName = $config.Config.SearchServiceApplicationName

Add-PSSnapin Microsoft.SharePoint.Powershell -Ea 0
Start-SPAssignment -Global

#Create Content Source
$SearchServiceApplication = Get-SPEnterpriseSearchServiceApplication $SearchServiceApplicationName

if (!$SearchServiceApplication)
{
    Write-Host "Search Service Application:" $SearchServiceApplicationName " - does not exists" -ForegroundColor Red
    break;
}
Write-Host "Search Service Application:" $SearchServiceApplicationName " - exists" -ForegroundColor Green

#get all content sources
$ExistingContentSources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchServiceApplication

#for each content source to create:
Write-Host ""
foreach( $contentsource in $config.config.ContentSources.ContentSource) 
{ 
    Write-Host $contentsource.Name 
    $SPContentSource = $false

    #check if the content source exists
    $ExistingContentSources | ForEach-Object {
        if ($_.Name.ToString() -eq $contentsource.Name)
        {
            Write-Host "Content Source:" $contentsource.Name " already exist."
            $SPContentSource = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchServiceApplication -Identity $_.Id

            if ($SPContentSource.Type -ne $contentsource.Type)
            {
                Write-Host "Content Source can not be updated because the type changed - it will be deleted/recreated!"
                $SPContentSource = Remove-SPEnterpriseSearchCrawlContentSource
                $SPContentSource = $false
            }

            return;
        }
    }

    
    #create the url collection
    $urls = @();
    if ($contentsource.Urls)
    {
        foreach($url in $contentsource.Urls.Split("`n"))
        {
            if ($url.Trim())
            {
                
                Write-Host  "`nUrl:" $url.Trim() -NoNewline
                $urls += $url.Trim()
            }
        }
    }
    else
    { 
        Write-Host  "ContentSource " $contentsource.Name " has no urls defined!" -ForegroundColor Red
        continue
    }

    $StartAddresses = [System.String]::Join(",", $urls)

    #if the content source does not exists, create it
    if (!$SPContentSource)
    {
        try
        {
        New-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchServiceApplication -Type $contentsource.Type -name $contentsource.Name -StartAddresses $StartAddresses -SharePointCrawlBehavior $contentsource.CrawlBehavior -ErrorAction Stop
        $SPContentSource = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchServiceApplication -Identity $contentsource.Name
        }
        catch
        {
            Write-Host "`nThere was an error creating the content source" $contentsource.Name " - most probable cause is that the url or scope is contained in a different content source. Error:" -ForegroundColor Red
            Write-Host "`t" $_.Exception -ForegroundColor Red
            continue
        }
    }

    #remove the existing crawl schedules
    if ($SPContentSource.FullCrawlSchedule)
    {
        $SPContentSource | Set-SPEnterpriseSearchCrawlContentSource -RemoveCrawlSchedule -ScheduleType Full
        
    }

    if ($SPContentSource.IncrementalCrawlSchedule)
    {
        $SPContentSource | Set-SPEnterpriseSearchCrawlContentSource -RemoveCrawlSchedule -ScheduleType Incremental
        
    }



    

    Write-Host
    Write-Host "`nSchedules:"

    #foreach Crawl Schedule
    foreach ($crawlSchedule in $contentsource.CrawlSchedules.CrawlSchedule)
    {
        
        Write-Host "`nScheduleType: " $crawlSchedule.Type

        if ($crawlSchedule.Repeat -eq "Monthly")
        {
            #set the monthly schedule
            $SPContentSource | Set-SPEnterpriseSearchCrawlContentSource -StartAddresses $StartAddresses -ScheduleType $crawlSchedule.Type -MonthlyCrawlSchedule -CrawlScheduleMonthsOfYear $crawlSchedule.MonthsOfYear -CrawlScheduleStartDateTime $crawlSchedule.StartDateTime
            
            Write-Host "`tSchedule: Monthly"
            Write-Host "`tMonths: " $crawlSchedule.MonthsOfYear
            Write-Host "`tStartdate: "$crawlSchedule.StartDateTime
        }
        elseif ($crawlSchedule.Repeat -eq "Weekly")
        {
            #set the weekly schedule
            $SPContentSource | Set-SPEnterpriseSearchCrawlContentSource -StartAddresses $StartAddresses -ScheduleType $crawlSchedule.Type -WeeklyCrawlSchedule -CrawlScheduleStartDateTime $crawlSchedule.StartDateTime -CrawlScheduleDaysOfWeek $crawlSchedule.DaysOfWeek  -CrawlScheduleRunEveryInterval $crawlSchedule.RunEveryInterval
            Write-Host "`tSchedule: Weekly"
            Write-Host "`tDays: " $crawlSchedule.DaysOfWeek
            Write-Host "`tStartdate: " $crawlSchedule.StartDateTime
        }
        elseif ($crawlSchedule.Repeat -eq "Daily")
        {
            $SPContentSource | Set-SPEnterpriseSearchCrawlContentSource -StartAddresses $StartAddresses -ScheduleType $crawlSchedule.Type -DailyCrawlSchedule -CrawlScheduleRunEveryInterval $crawlSchedule.RunEveryInterval -CrawlScheduleRepeatInterval $crawlSchedule.RepeatInterval -CrawlScheduleRepeatDuration $crawlSchedule.RepeatDuration
            Write-Host "`tSchedule: Daily"
            Write-Host "`tRun every: " $crawlSchedule.RunEveryInterval " day(s)"
            Write-Host "`tRepeat Interval: " $crawlSchedule.RepeatInterval " minutes"
            Write-Host "`tRepeat Interval: " $crawlSchedule.RepeatDuration " minutes"
        }
    }
    Write-Host "`n"
}

Stop-SPAssignment -Global
Write-Host -ForegroundColor Green "done."