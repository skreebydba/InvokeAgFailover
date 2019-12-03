<#
.SYNOPSIS
  Name: InvokeAgFailoverFunction.ps1
  The purpose of this script is to failover a SQL Server Availability group.
  
.DESCRIPTION
  The purpose of this script is to failover a SQL Server Availability group.  It confirms that the primary and secondary replicas provided are in a state to
  allow failover with no data loss.  
  yourself.
.PARAMETER parameter1
  The first parameter

.PARAMETER parameter2
  The second parameter

.PARAMETER parameter3
  The third parameter
      
.NOTES
    Updated: 2019-08-07        Initial build.
    Release Date: 2019-08-07
   
  Author: Frank Gill, Concurrency, Inc.

.EXAMPLE
  Do something.
  Do-Something -parameter1 SomeValue -parameter2 AnotherValue -parameter3 YetAnotherValue

.EXAMPLE
  Do something else.
  Do-Something -parameter1 ADifferentValue -parameter2 AnotherDifferentValue -parameter3 YetAnotherDifferentValue

#>
Function Do-Something{
  [CmdletBinding()]

    PARAM ( 
        [Parameter(Mandatory=$true)]
        [string]
        $parameter1,
        [Parameter(Mandatory=$true)]
        [string]
        $parameter2,
        [Parameter(Mandatory=$true)]
        [string]
        $parameter3
    )
  
  Begin{
    Write-Host "Start Do-Something function..."
  }
  
  Process{
    Try{
        Write-Host "Doing something with $parameter1, $parameter2, and $parameter3" -ForegroundColor Magenta;        
    }
    
    Catch{
      "Something went wrong.: $($PSItem.ToString())"
      Break
    }

  }
  
  End{
    If($?){ # only execute if the function was successful.
      Write-Host "Completed Do-Something function." -ForegroundColor Yellow;
    }
  }
}

Do-Something -parameter1 "Snap" -parameter2 "Crackle" -parameter3 "Pop";