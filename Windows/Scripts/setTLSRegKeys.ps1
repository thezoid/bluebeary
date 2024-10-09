function setRegKey {
     param(
         [string]$Path,
         [string]$Name,
         [int]$Value
     )
     if (-not (Test-Path $Path)) {
         New-Item $Path -Force | Out-Null
     }
     New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
 }
 
 $protocols = @(
     @{Protocol="SSL 2.0"; Type="Server"; Enabled=0; DisabledByDefault=1},
     @{Protocol="SSL 2.0"; Type="Client"; Enabled=0; DisabledByDefault=1},
     @{Protocol="SSL 3.0"; Type="Server"; Enabled=0; DisabledByDefault=1},
     @{Protocol="SSL 3.0"; Type="Client"; Enabled=0; DisabledByDefault=1},
     @{Protocol="TLS 1.0"; Type="Server"; Enabled=0; DisabledByDefault=1},
     @{Protocol="TLS 1.0"; Type="Client"; Enabled=0; DisabledByDefault=1},
     @{Protocol="TLS 1.1"; Type="Server"; Enabled=0; DisabledByDefault=1},
     @{Protocol="TLS 1.1"; Type="Client"; Enabled=0; DisabledByDefault=1},
     @{Protocol="TLS 1.2"; Type="Server"; Enabled=1; DisabledByDefault=0},
     @{Protocol="TLS 1.2"; Type="Client"; Enabled=1; DisabledByDefault=0},
     @{Protocol="TLS 1.3"; Type="Server"; Enabled=1; DisabledByDefault=0},
     @{Protocol="TLS 1.3"; Type="Client"; Enabled=1; DisabledByDefault=0}
 )
 
 foreach ($protocol in $protocols) {
     $keyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$($protocol.Protocol)\$($protocol.Type)"
     setRegKey -Path $keyPath -Name "Enabled" -Value $protocol.Enabled
     setRegKey -Path $keyPath -Name "DisabledByDefault" -Value $protocol.DisabledByDefault
 }
 