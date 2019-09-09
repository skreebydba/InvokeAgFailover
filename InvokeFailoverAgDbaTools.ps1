$primary = "fbgsql2019vm2";
$secondary = "fbgsql2019vm1";
$primarycheck = 0;
$secondarycheck = 0;
$agname = "fbgsql2019ag"
$replicaroles = Get-DbaAgReplica -SqlInstance $primary -AvailabilityGroup $agname | Select-Object -Property Name, Role, RollupSynchronizationState;
$replicaroles;ForEach($replicarole in $replicaroles)
{
    if($primary -eq $replicarole.Name)
    {
        if(($replicarole.Role -eq "Primary") -and ($replicarole.RollupSynchronizationState -eq "Synchronized"))
        {
            $primarycheck = 1;
        }
    }
    if($secondary -eq $replicarole.Name) 
    {    
        if(($replicarole.Role -eq "Secondary") -and ($replicarole.RollupSynchronizationState -eq "Synchronized"))
        {
            $secondarycheck = 1;
        }
    }
}

if(($primarycheck -eq 1) -and ($secondarycheck -eq 1))
{
    Invoke-DbaAgFailover -SqlInstance $secondary -AvailabilityGroup $agname -Confirm:$false;
}
else
{
    if($primarycheck -eq 0)
    {
        Write-Host "$primary is not the primary replica or it is in a state that will allow data loss."
    }
    if($secondarycheck -eq 0)
    {
        Write-Host "$secondary is not a secondary replica or it is in a state that will allow data loss."
    }
}

