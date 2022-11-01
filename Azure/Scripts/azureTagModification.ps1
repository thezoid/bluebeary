$vmNames = @("testtestest")
$tagsToAdd = @{
     tag1 = "tag1"; 
     tag2 = "tag2"; 
     tag3 = "tag3"
}
$tagsToRemove = @("badTagVal1", "badTagVal2", "badTagVal3")
$rgName = "TemplateTesting"

foreach ($vm in $vmNames) {
     #get our tags
     $azVM = Get-AzResource -ResourceGroupName $rgName -Name $vm
     $tags = $azVM.Tags
    
     #get all keys to remove
     $kill = New-Object System.Collections.ArrayList
     foreach ($k in $tags.Keys) {
          if ($tagsToRemove -contains $($tags.Item($k) )){
               $null = $kill.Add($k)
          } 
     }

     #remove all tags to be removed
     foreach ($k in $kill) {
          $tags.Remove($k)
     }

     #add all tags to add
     foreach ($t in $tagsToAdd) {
          if (!$tags -contains $t) {
               $tags += $t
          }
     }

     #set vm's tags to the processed key-value pair list
     Set-AzResource -ResourceGroupName $rgName -Name $vm -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $tags
}