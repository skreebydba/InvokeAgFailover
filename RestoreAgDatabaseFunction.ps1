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
  Run the Get-Example script to create the c:\example folder:
  Get-Example -Directory c:\example

.EXAMPLE 
  Run the Get-Example script to create the folder c:\example and
  overwrite any existing folder in that location:
  Get-Example -Directory c:\example -force

See Help about_Comment_Based_Help for more .Keywords

# Comment-based Help tags were introduced in PS 2.0
#requires -version 2
#>

[CmdletBinding()]

PARAM ( 
    [string]$InitialDirectory = $(throw "-InitialDirectory is required."),
    [switch]$Add = $false
)
#----------------[ Declarations ]------------------------------------------------------

# Set Error Action
# $ErrorActionPreference = "Continue"

# Dot Source any required Function Libraries
# . "C:\Scripts\Functions.ps1"

# Set any initial values
# $Examplefile = "C:\scripts\example.txt"

#----------------[ Functions ]---------------------------------------------------------
Function MyExampleFunction{
  Param()
  
  Begin{
    Write-Host "Start example function..."
  }
  
  Process{
    Try{
      "Do Something here"
    }
    
    Catch{
      "Something went wrong."
      Break
    }

  }
  
  End{
    If($?){ # only execute if the function was successful.
      Write-Host "Completed example function."
    }
  }
}

#----------------[ Main Execution ]----------------------------------------------------

# Script Execution goes here