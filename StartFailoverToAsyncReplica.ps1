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
        
        <# Get a list of replicas for the Availability Group to use to resume movement after failover #>
        [System.Collections.ArrayList]$replicas = (Get-DbaAvailabilityGroup -SqlInstance $primary).AvailabilityReplicas.Name;
        <# Remove the new primary from the replica list #>
        $replicas.Remove($asyncsecondary);

        <# Get the synchronization state of the async secondary for use in the while loop below #>
        $syncstate = Get-DbaAgReplica -SqlInstance $asyncsecondary -AvailabilityGroup $agname | Where-Object -Property Name -EQ $asyncsecondary | Select-Object -ExpandProperty RollupSynchronizationState;

        <# Set the synchronization state for the async secondary to Synchronous #>
        Set-DbaAgReplica -SqlInstance $primary -AvailabilityGroup $agname -Replica $asyncsecondary -AvailabilityMode SynchronousCommit;

        <# Check the $syncstate variable until it flips to Synchronizing, indicating the failover can occur without data loss #>
        while($syncstate -eq "Synchronizing")
        {
            $syncstate = Get-DbaAgReplica -SqlInstance $asyncsecondary -AvailabilityGroup $agname | Where-Object -Property Name -EQ $asyncsecondary | Select-Object -ExpandProperty RollupSynchronizationState;
            Write-Host $syncstate -ForegroundColor Yellow;
        }

        <# Fail the Availability Group over to the formerly asynchronous secondary #>
        Invoke-DbaAgFailover -SqlInstance $asyncsecondary -AvailabilityGroup $agname -Force;

        <# Resume data movement for the new secondary replicas, in case it is suspended #>
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