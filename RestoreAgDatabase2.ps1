<# Availability Group name #>
$ag = "fbgsql2019ag"
,# Database to restore #>
$database = "WideWorldImporters";
<# Primary instance #>
$primary = "fbgsql2019vm1";
<# Secondary instances - for multiple secondaries, wrap the comma-delimited list in @() #>
$secondaries = @("fbgsql2019vm2","fbgsql2019vm3");

$exists = Get-DbaDatabase -SqlInstance $primary -Database $database;

if($exists)
{
    <# Remove the database to be restored from the Availability Group#>
    Remove-DbaAgDatabase -SqlInstance $primary -Database $database -AvailabilityGroup $ag -Confirm:$false;
    <# Drop the database from all secondary replicas #>
    Remove-DbaDatabase -SqlInstance $secondaries -Database $database -Confirm:$false;
}
<# Restore the database to the promary replica #>
Restore-DbaDatabase -SqlInstance $primary -Path "C:\backup\wwi_full_20190625.bak" -DatabaseName $database -WithReplace;

<# Add the database back to the AG - this will execute the following steps
    Run FULL and LOG backups on the primary replica
    Restore FULL and LOG backups on all secondary replicas
    Join the database to the AG on all replicas 
    It assumes that the SQL Server services accounts for all replicas have read/write access to the _sharedPath #>
Add-DbaAgDatabase -SqlInstance $primary -AvailabilityGroup fbgsql2019ag -Database $database -SeedingMode Manual -SharedPath "\\$primary\backup";
