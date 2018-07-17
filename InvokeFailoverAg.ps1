<#
    Author: Frank Gill, Concurrency
    Date: 2017-11-17 
#>
function Invoke-AgFailover {
  <#
  .SYNOPSIS
  Checks specified instance for healthy, synchronous Availability Groups running as secondary and
  fails them over
  .DESCRIPTION
  Checks the instance passed in for healthy, synchronous Availability Groups running as secondary and
  fails them over.  If the instance is not hosting secondary replicas, a message will be output.
  If there are AGs running as secondary, a message will output for each, including AG name, destination,
  and failover duration.  
  .EXAMPLE
  Invoke-AgFailover -Instance YourSecondaryInstance -NoExec 0;
  Any Availability Groups running as secondary on YourSecondaryInstance will be failed over.
  .EXAMPLE
  Invoke-AgFailover -Instance YourSecondaryInstance -NoExec 1;
  If Availability Groups are running as secondary on YourSecondaryInstance, T-SQL commands for each AG failover
  will be generated and written to C:\AGFailover\failover_YourAgName_YYYYMMDD_HHMMSS.sql.
  .PARAMETER Instance
  The instance to check for secondary replicas.
  .PARAMETER NoExec
  Set to 1 to generate T-SQL script for failover.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    Position = 1,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='Which instance do you want to fail the availability group from?')]
    [Alias('primary')]
    [string[]]$primaryinstance,

    [Parameter(Mandatory=$True,
    Position = 2,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='Which instance do you want to fail the availability group from?')]
    [Alias('secondary')]
    [string[]]$secondaryinstance,

    [Parameter(Mandatory=$True,
    Position = 3,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What availability group do you want to failover?')]
    [Alias('availabilitygroup')]
    [string[]]$agname,

    [Parameter(Mandatory=$True,
    Position = 4,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
        HelpMessage='Set to 1 if you want to execute the database restore.  Otherwise enter 0.')]
    [Alias('dontrun')]
    [string]$noexec 
  )
  process
  {
    <# If the $noexec is set to 1, create file path to hold out files #>
    if($noexec -eq 1)
    {
        $rundate = Get-Date -Format yyyyMMdd_HHmmss;
        $outpath = "C:\AgFailover";
        if((Test-Path -Path $outpath) -eq $true)
        {
            Remove-Item -Path "$outpath\*" -Recurse;
        }
        else
        {
            New-Item -Path $outpath -ItemType Directory;
        }
    }

    <# Create query to check for failover-eligible AGs #>
    $query = "SELECT 1 
    FROM sys.dm_hadr_availability_replica_states r
    INNER JOIN sys.availability_replicas ar
    ON ar.group_id = r.group_id
    AND ar.replica_id = r.replica_id
    INNER JOIN sys.availability_groups g
    ON g.group_id = ar.group_id
    WHERE r.role_desc = N'PRIMARY'
    AND r.recovery_health_desc = N'ONLINE'
    AND r.synchronization_health_desc = N'HEALTHY'
    AND ar.availability_mode_desc = N'SYNCHRONOUS_COMMIT'
    AND g.name = '$agname';"

    $query;

    <# Execute failover-eligible query #>
    $aghealth = Invoke-Sqlcmd -ServerInstance "$primaryinstance" -Database master -Query $query;

    $secondaryinstance;

    <# Output message if there are no failover-eligible AGs #>
    if($aghealth.Column1 -ne 1)
    {
        Write-Output "There are no Availability Group replicas available to fail over to $instance."
    }
    else
    {
        $failoverquery = "ALTER AVAILABILITY GROUP [$agname] FAILOVER;"
        Invoke-Sqlcmd -ServerInstance "$secondaryinstance" -Database master -Query $failoverquery;
        Write-Output $failoverquery;
    }
}
}