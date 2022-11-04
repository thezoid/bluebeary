Param([Parameter(Mandatory = $true)][string]$targets, [Parameter(Mandatory = $true)][string]$ports)

 $date = Get-Date -format "yyyy-MMM-dd_hhmmss"
 $logpath = "logs/$($date)_reset.log"
 if(!$logpath){
      New-Item $logpath
 } 
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path $logpath -append

Write-Host "------------------------------"
Write-Host "UDP Port Tester"
Write-Host "------------------------------"

#get the machines to test
$machinesToTestPrompt = $targets #Read-Host -Prompt "What machines do you want to test? Separate multiple entries with a comma`n"
$machinesToTest = @()
$machinesToTestPrompt.Split(",") | ForEach {
     $toAdd = $_ -replace (' ')
     $machinesToTest += $toAdd
}
#get the ports to test
$portsToTestPrompt = $ports #Read-Host -Prompt "What ports do you want to test? Separate multiple entries with a comma`n" 
$portsToTest = @()
$portsToTestPrompt.Split(',') | ForEach {
     $toAdd = $_ -replace (' ')
     $portsToTest += $toAdd
}

$report = @()  
foreach ($machine in $machinesToTest) {
     $report += "`n`n------------------------------`nTesting ports on: $machine`n------------------------------"
     foreach ($port in $portsToTest) {
          #Create temporary holder   
          $temp = "" | Select Server, Port, TypePort, Open, Notes                                     
          #Create object for connecting to port on computer  
          $udpobject = new-Object system.Net.Sockets.Udpclient
          #Set a timeout on receiving message 
          $udpobject.client.ReceiveTimeout = 10000 #10000 ms  = 10s
          #Connect to remote machine's port                
          Write-Verbose "Making UDP connection to remote server" 
          $udpobject.Connect("$machine", $port) 
          #Sends a message to the host to which you have connected. 
          Write-Verbose "Sending message to remote host" 
          $a = new-object system.text.asciiencoding 
          $byte = $a.GetBytes("$(Get-Date)") 
          [void]$udpobject.Send($byte, $byte.length) 
          #IPEndPoint object will allow us to read datagrams sent from any source.  
          Write-Verbose "Creating remote endpoint" 
          $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0) 
          Try { 
               #Blocks until a message returns on this socket from a remote host. 
               Write-Verbose "Waiting for message return" 
               $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
               [string]$returndata = $a.GetString($receivebytes)
               If ($returndata) {
                    Write-Verbose "Connection Successful"  
                    #Build report  
                    $temp.Server = $machine 
                    $temp.Port = $port  
                    $temp.TypePort = "UDP"  
                    $temp.Open = "True"  
                    $temp.Notes = $returndata   
                    $udpobject.close()   
               }                       
          }
          Catch { 
               If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                    #Close connection  
                    $udpobject.Close()  
                    #Make sure that the host is online and not a false positive that it is open 
                    If (Test-Connection -comp $machine -count 1 -quiet) { 
                         Write-Verbose "Connection Open"  
                         #Build report  
                         $temp.Server = $machine
                         $temp.Port = $port
                         $temp.TypePort = "UDP"  
                         $temp.Open = "True"  
                         $temp.Notes = "" 
                    }
                    Else { 
                         <# 
            It is possible that the host is not online or that the host is online,  
            but ICMP is blocked by a firewall and this port is actually open. 
            #> 
                         Write-Verbose "Host may be unavailable"  
                         #Build report  
                         $temp.Server = $machine 
                         $temp.Port = $port
                         $temp.TypePort = "UDP"  
                         $temp.Open = "False"  
                         $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                    }                         
               }
               ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                    #Close connection  
                    $udpobject.Close()  
                    Write-Verbose "Connection Timeout"  
                    #Build report  
                    $temp.Server = $machine
                    $temp.Port = $port
                    $temp.TypePort = "UDP"  
                    $temp.Open = "False"  
                    $temp.Notes = "Connection to Port Timed Out"                         
               }
               Else {                      
                    $udpobject.close() 
               } 
          }     
          #Merge temp array with report              
          $report += $temp 
     }
}
Write-Host "`n`n------------------------------`nResults`n------------------------------"
$report

if("tmp/out.txt"){
     $report | Set-Content "tmp/out.txt"
}else{
     New-Item -Path "tmp/out.txt"
     $report | Set-Content "tmp/out.txt"
}
Stop-Transcript












# foreach ($machine in $machinesToTest) {
#      Write-Host "`n`n`n`n------------------------------`nTesting ports on: $machine`n------------------------------"
#      foreach ($port in $portsToTest) {
#           Write-Host "Testing port: $port"
#           $udpobject = New-Object system.Net.Sockets.Udpclient($port)
#           $a = New-Object system.text.asciiencoding
#           $byte = $a.GetBytes("$(Get-Date)")
#           $udpobject.Connect($machine, $port)
#           [void]$udpobject.Send($byte, $byte.length)
#           $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)

#           Blocks until a message returns on this socket from a remote host.
#           $receivebytes = $udpobject.Receive([ref]$remoteendpoint)
 
#           Convert returned data into string format
#           [string]$returndata = $a.GetString($receivebytes)
 
#           Uses the IPEndPoint object to show that the host responded.
#           Write-Host "This is the message you received: $($returndata.ToString())"
#           Write-Host "This message was sent from: $($remoteendpoint.address.ToString()) on their port number: $($remoteendpoint.Port.ToString())"

          
#           $udpobject.Close()
#      }
# }

#if () {
#     Write-Host "Success: $Machine - $port tested successfully"
#}
#else {
#     Write-Host "Failure: $Machine - $port tested unsuccessfully"
#}