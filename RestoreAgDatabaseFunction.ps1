<#
.SYNOPSIS
  Name: RestoreAgDatabase.ps1
  The purpose of this script is to restore a SQL Server database and add it to an Availability Group.
  
.DESCRIPTION
  The purpose of this script is to restore a SQL Server database and add it to an Availability Group.  If the database exists in the Availability Group,
  it will be removed from the Availability Group and dropped on all secondaries.  Once the database is restored on the primary replica, it will be added to the
  secondaries.  For SQL Server versions earlier than 2016, backup/restore will be used.  By default, the backups will be written to \\$primary\backup.  
  This method requires a file share location that all of the replicas
  can see.  For 2016 and later, automatic seeding will be used to initialize the secondaries.
.PARAMETER ag
  The Availability Group the database will be restored to.
  
.PARAMETER database
  The database to be restored.

.PARAMETER primary
  The primary replica for the Availability Group.
  
.PARAMETER secondaries
  The secondary replica(s) for the Availability Group.  If there is more than one secondary, define parameter values as an array, 
  $secondaries = @("fbgsql2019vm2","fbgsql2019vm3");

.PARAMETER backup
  The backup file to be restored.

.NOTES
    Updated: 2019-07-01        Initial build.
    Release Date: 2019-07-01
   
  Author: Frank Gill, Concurrency, Inc.

.EXAMPLE
  Restore Availability Group database, using backup/restore to initialize secondary replicas (for SQL versions less than 2016):
  Restore-AgDatabase -AvailabilityGroup MyAgName -database MyDatabase -primary MyPrimary - secondaries @("Secondary1","Secondary2") -backup "C:\Backup\MyBackup.bak" -fileshare "\\MyPrimary\Backup";

.EXAMPLE 
  Restore Availability Group database, using automatic seeding to initialize secondary replicas (for SQL versions greater than or equal to 2016):
  Restore-AgDatabase -AvailabilityGroup MyAgName -database MyDatabase -primary MyPrimary - secondaries @("Secondary1","Secondary2") -backup "C:\Backup\MyBackup.bak";

See Help about_Comment_Based_Help for more .Keywords

# Comment-based Help tags were introduced in PS 2.0
#requires -version 2
#>


#----------------[ Declarations ]------------------------------------------------------

# Set Error Action
# $ErrorActionPreference = "Continue"

# Dot Source any required Function Libraries
# . "C:\Scripts\Functions.ps1"

# Set any initial values
# $Examplefile = "C:\scripts\example.txt"

#----------------[ Functions ]---------------------------------------------------------
Function Restore-AgDatabase{
  [CmdletBinding()]

    PARAM ( 
        [string]$AvailabilityGroup = $(throw "-AvailabilityGroup is required."),
        [string]$Database = $(throw "-Database is required."),
        [string]$Primary = $(throw "-Primary is required."),
        [string[]]$Secondaries = $(throw "-Secondaries is required."),
        [string]$Backup = $(throw "-Backup is required."),
        [string]$Fileshare
    )
  
  Begin{
    Write-Host "Start Restore-AgDatabase function..."
  }
  
  Process{
    Try{
        $exists = Get-DbaDatabase -SqlInstance $primary -Database $database;

        if($exists)
        {
            <# Remove the database to be restored from the Availability Group#>
            Remove-DbaAgDatabase -SqlInstance $primary -Database $database -AvailabilityGroup $AvailabilityGroup -Confirm:$false;
            <# Drop the database from all secondary replicas #>
            Remove-DbaDatabase -SqlInstance $secondaries -Database $database -Confirm:$false;
        }
        <# Restore the database to the promary replica #>
        Restore-DbaDatabase -SqlInstance $primary -Path $backup -DatabaseName $database -WithReplace;

        $version = Invoke-DbaQuery -SqlInstance $primary -Database master -Query "SELECT SERVERPROPERTY('productversion')";
        $majorversion = $version.Column1.Substring(0,2);

        <# Check SQL Server version. If 2016 or greater, use automatic seeding to initialize the secondaries.  If less than 2016, use backup/restore #>
        if($majorversion -ge 13)
        {
            Add-DbaAgDatabase -SqlInstance $primary -AvailabilityGroup $AvailabilityGroup -Database $database -SeedingMode Automatic;
        }
        else
        {
        <# Add the database back to the AG - this will execute the following steps
            Run FULL and LOG backups on the primary replica
            Restore FULL and LOG backups on all secondary replicas
            Join the database to the AG on all replicas 
            It assumes that the SQL Server services accounts for all replicas have read/write access to the -SharedPath #>
            Add-DbaAgDatabase -SqlInstance $primary -AvailabilityGroup $AvailabilityGroup -Database $database -SeedingMode Manual -SharedPath $fileshare;
        }
    }
    
    Catch{
      "Something went wrong."
      Break
    }

  }
  
  End{
    If($?){ # only execute if the function was successful.
      Write-Host "Completed Restore-AgDatabase function."
    }
  }
}

#----------------[ Main Execution ]----------------------------------------------------

# Script Execution goes here
  Restore-AgDatabase -AvailabilityGroup fbgsql2019ag -database WideWorldImporters -primary fbgsql2019vm1 -Secondaries "fbgsql2019vm2","fbgsql2019vm3" -backup "C:\backup\wwi_full_20190625.bak";