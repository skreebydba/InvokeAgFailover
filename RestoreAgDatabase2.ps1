<# Availability Group name #>
$ag = "fbgsql2019ag"
,# Database to restore #>
$database = "WideWorldImporters";
<# Primary instance #>
$primary = "fbgsql2019vm1";
<# Secondary instances - for multiple secondaries, wrap the comma-delimited list in @() #>
$secondaries = @("fbgsql2019vm2","fbgsql2019vm3");
<# Backup file to be restored #>
$backup = "C:\backup\wwi_full_20190625.bak";
<# File share path for backup/restore for AG initialization
   All replicas require access to this share #>
$fileshare = "\\$primary\backup";

$exists = Get-DbaDatabase -SqlInstance $primary -Database $database;

if($exists)
{
    <# Remove the database to be restored from the Availability Group#>
    Remove-DbaAgDatabase -SqlInstance $primary -Database $database -AvailabilityGroup $ag -Confirm:$false;
    <# Drop the database from all secondary replicas #>
    Remove-DbaDatabase -SqlInstance $secondaries -Database $database -Confirm:$false;
}
<# Restore the database to the promary replica #>
Restore-DbaDatabase -SqlInstance $primary -Path $backup -DatabaseName $database -WithReplace;

$version = Invoke-DbaQuery -SqlInstance fbgsql2019vm1 -Database master -Query "SELECT SERVERPROPERTY('productversion')";
$majorversion = $version.Column1.Substring(0,2);

<# Check SQL Server version. If 2016 or greater, use automatic seeding to initialize the secondaries.  If less than 2016, use backup/restore #>
if($majorversion -ge 13)
{
    Add-DbaAgDatabase -SqlInstance $primary -AvailabilityGroup fbgsql2019ag -Database $database -SeedingMode Automatic;
}
else
{
<# Add the database back to the AG - this will execute the following steps
    Run FULL and LOG backups on the primary replica
    Restore FULL and LOG backups on all secondary replicas
    Join the database to the AG on all replicas 
    It assumes that the SQL Server services accounts for all replicas have read/write access to the -SharedPath #>
    Add-DbaAgDatabase -SqlInstance $primary -AvailabilityGroup fbgsql2019ag -Database $database -SeedingMode Manual -SharedPath $fileshare;
}
