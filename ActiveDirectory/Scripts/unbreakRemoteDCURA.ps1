$sb = {
     $user = "Domain Admins"
     $tmp = [System.IO.Path]::GetTempFileName()
     secedit.exe /export /cfg $tmp
     $settings = Get-Content -Path $tmp
     $account = New-Object System.Security.Principal.NTAccount($user)
     $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
     for($i=0;$i -lt $settings.Count;$i++){
         if($settings[$i] -match "SeNetworkLogonRight")
          {
               $settings[$i] += ",*$($sid.Value)"
          }
          if($settings[$i] -match "SeDenyNetworkLogonRight")
          {
               $settings[$i] = "SeDenyNetworkLogonRight ="
          }
          if($settings[$i] -match "SeDenyRemoteInteractiveLogonRight")
          {
              $settings[$i] = "SeDenyRemoteInteractiveLogonRight ="
          }
         if($settings[$i] -match "SeDenyInteractiveLogonRight")
          {
             $settings[$i] = "SeDenyInteractiveLogonRight ="
          }
          if($settings[$i] -match "SeDeny*")
          {
             $settings[$i] = "$($settings[$i].split("=")[0])="
          }
     }
     $settings | Out-File $tmp
     cat $tmp
     secedit.exe /configure /db secedit.sdb /cfg $tmp  /areas User_RIGHTS
     Remove-Item -Path $tmp
}
$targets = (
     "dchostname-01",
     "dchostname-02",
     "dchostname-03"
)
foreach($target in $targets){
     invoke-command -ScriptBlock $sb -ComputerName $target
}