<#
.SYNOPSIS
  Name: StartFailoverToAsyncReplica.ps1
  The purpose of this script is to fail over to an asynchronous replica.
  
.DESCRIPTION
  The purpose of this script is to fail over to an asynchronous replica.  The script switches the async replica to sync.  Once the secondary is in a 
  synchronized state, the Availability Group is failed over.

.PARAMETER asyncsecondary
  The async secondary replica you want to fail over to.

.PARAMETER agname
  The Availability Group being failed over.

.PARAMETER resume
  Resume data movement to the new secondary replicas. Required because failover is being run with the -Force parameter.

.NOTES
    Updated: 2019-12-03       Initial build.
    Release Date: TBD
   
  Author: Frank Gill, Concurrency, Inc.

.EXAMPLE
  Failover to async replica with no data loss.  Resume data movement to the new secondary replicas.
  Start-FailoverToAsyncReplica -asyncsecondary replica2 -agname yourag -resume:$true;

  Failover to async replica with no data loss.  Do not resume data movement to the new secondary replicas.
  Start-FailoverToAsyncReplica -asyncsecondary replica2 -agname yourag -resume:$false;

  Failover to async replica with no data loss.  Resume data movement to the new secondary replicas and see all informational messages.
  Start-FailoverToAsyncReplica -asyncsecondary replica2 -agname yourag -resume:$true -Verbose;

#>
Function Start-FailoverToAsyncReplica{
  [CmdletBinding()]

    PARAM ( 
        [Parameter(Mandatory=$true)]
        [string]
        $asyncsecondary,
        [Parameter(Mandatory=$true)]
        [string]
        $agname,
        [Parameter(Mandatory=$false)]
        [switch]
        $resume
    )
  
  Begin{
    Write-Verbose "Start Start-FailoverToAsyncReplica function..."
    Import-Module DBATools;
  }
  
  Process{
    Try{

        $asyncsecondary = $asyncsecondary.ToUpper();
        $ag = Get-DbaAvailabilityGroup -SqlInstance $primary -AvailabilityGroup $agname;
        $primary = (Get-DbaAvailabilityGroup -SqlInstance $asyncsecondary -AvailabilityGroup $agname).PrimaryReplica;

        if(!$ag)
        {
            Throw "Availability group $agname does not exist.  Please check the name and run the function again.";
        }
        
        <# Get a list of replicas for the Availability Group to use to resume movement after failover #>
        [System.Collections.ArrayList]$replicas = (Get-DbaAvailabilityGroup -SqlInstance $primary -AvailabilityGroup $agname).AvailabilityReplicas.Name;

        $primaryexists = $replicas.Contains($primary);
        $secondaryexists = $replicas.Contains($asyncsecondary);

        if(!$primaryexists)
        {
            Throw "Primary replica $primary does not exist in Availability Group $agname. Please check the value and rerun the function."
        }
        
        if(!$secondaryexists)
        {
            Throw "Secondary replica $asyncsecondary does not exist in Availability Group $agname. Please check the value and rerun the function."
        }

        <# Remove the new primary from the replica list #>
        $replicas.Remove($asyncsecondary);

        <# Get the synchronization state of the async secondary for use in the while loop below #>
        $syncstate = Get-DbaAgReplica -SqlInstance $asyncsecondary -AvailabilityGroup $agname | Where-Object -Property Name -EQ $asyncsecondary | Select-Object -ExpandProperty RollupSynchronizationState;

        <# Set the synchronization state for the async secondary to Synchronous #>
        Set-DbaAgReplica -SqlInstance $primary -AvailabilityGroup $agname -Replica $asyncsecondary -AvailabilityMode SynchronousCommit;

        <# Check the $syncstate variable until it flips to Synchronizing, indicating the failover can occur without data loss #>
        #TODO Add timeout process - Error or flip back to async?

        $synccheck = Get-Date;
        while(($syncstate -eq "Synchronizing") -and ($synccheck.AddMinutes(5) -gt $(Get-Date)))
        {
            $syncstate = Get-DbaAgReplica -SqlInstance $asyncsecondary -AvailabilityGroup $agname | Where-Object -Property Name -EQ $asyncsecondary | Select-Object -ExpandProperty RollupSynchronizationState;
            #TODO Change to Write-Verbose or some other Write- command
            Write-Host $syncstate -ForegroundColor Yellow;
            Start-Sleep -Seconds 10;
        }

        <# Fail the Availability Group over to the formerly asynchronous secondary #>
        Invoke-DbaAgFailover -SqlInstance $asyncsecondary -AvailabilityGroup $agname -Force;

        <# Resume data movement for the new secondary replicas, in case it is suspended
           Skip this step by setting $resume = Y #>
        if($resume -eq $true)
        {
            Get-DbaAgDatabase -SqlInstance $replicas -AvailabilityGroup $agname | Resume-DbaAgDbDataMovement -Confirm:$false;        
        }

        #TODO - Add warning/error if movement does not resume
        [System.Collections.ArrayList]$secondaries = (Get-DbaAvailabilityGroup -SqlInstance $asyncsecondary -AvailabilityGroup $agname).AvailabilityReplicas.Name;
        $secondaries.Remove($asyncsecondary);

        <# Check if data movement is resumed.  If not, output an error.  If so, flip the secondaries to async. #>
        $suspended = (Get-DbaAgDatabase -SqlInstance $secondaries -AvailabilityGroup $agname).IsSuspended;
        if($suspended.Contains("true"))
        {
            Write-Warning "Data movement is suspended for one or more databases."
        }
        else
        {
            Write-Verbose "Data movement is resumed for all databases."
            Set-DbaAgReplica -SqlInstance $primary -AvailabilityGroup $agname -Replica $secondaries -AvailabilityMode AsynchronousCommit;
        }
        
    }
    
    Catch{
      Write-Warning "Something went wrong.: $PSItem";
      $_;
    }

  }
  
  End{
    If($?){ # only execute if the function was successful.
      Write-Verbose "Completed Start-FailoverToAsyncReplica function.";
    }
  }
}