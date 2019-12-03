<#
.SYNOPSIS
  Name: StartFailoverToAsyncReplica.ps1
  The purpose of this script is to fail over to an asynchronous replica.
  
.DESCRIPTION
  The purpose of this script is to fail over to an asynchronous replica.  The script switches the async replica to sync.  Once the secondary is in a synchronized state,
  the Availability Group is failed over.
.PARAMETER primary
  The current primary replica for the Availability Group.

.PARAMETER asyncsecondary
  The async secondary replica you want to fail over to.

.PARAMETER agname
  The Availability Group being failed over.
      
.NOTES
    Updated: 2019-12-03       Initial build.
    Release Date: TBD
   
  Author: Frank Gill, Concurrency, Inc.

.EXAMPLE
  Failover to async replica with no data loss.
  Start-FailoverToAsyncReplica -primary replica1 -secondary replica2 -agname yourag

#>
Function Start-FailoverToAsyncReplica{
  [CmdletBinding()]

    PARAM ( 
        [Parameter(Mandatory=$true)]
        [string]
        $primary,
        [Parameter(Mandatory=$true)]
        [string]
        $asyncsecondary,
        [Parameter(Mandatory=$true)]
        [string]
        $agname
    )
  
  Begin{
    Write-Host "Start Start-FailoverToAsyncReplica function..."
  }
  
  Process{
    Try{

        [System.Collections.ArrayList]$replicas = (Get-DbaAvailabilityGroup -SqlInstance $primary).AvailabilityReplicas.Name;
        $replicas.Remove($asyncsecondary);

        Set-DbaAgReplica -SqlInstance $primary -AvailabilityGroup fbg2017ag -Replica $asyncsecondary -AvailabilityMode SynchronousCommit;

        $syncstate = "Synchronizing";
        while($syncstate -eq "Synchronizing")
        {
            $syncstate = Get-DbaAgReplica -SqlInstance $asyncsecondary -AvailabilityGroup $agname | Where-Object -Property Name -EQ $asyncsecondary | Select-Object -ExpandProperty RollupSynchronizationState;
            Get-DbaAgReplica -SqlInstance $asyncsecondary;
            Write-Host $syncstate -ForegroundColor Yellow;
        }

        Invoke-DbaAgFailover -SqlInstance $asyncsecondary -AvailabilityGroup $agname -Force;

        Get-DbaAgDatabase -SqlInstance $replicas | Resume-DbaAgDbDataMovement -Confirm:$false        
    }
    
    Catch{
      "Something went wrong.: $($PSItem.ToString())"
      Break
    }

  }
  
  End{
    If($?){ # only execute if the function was successful.
      Write-Host "Completed Start-FailoverToAsyncReplica function." -ForegroundColor Yellow;
    }
  }
}

Start-FailoverToAsyncReplica -parameter1 "Snap" -parameter2 "Crackle" -parameter3 "Pop";