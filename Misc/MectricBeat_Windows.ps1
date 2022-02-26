param(
    $metricbeatzipurl="https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.14.0-windows-x86_64.zip"
)
#download zip
Write-host "Attempting to download $metricbeatzipurl to c:\temp\metricbeat.zip"
Invoke-WebRequest -Uri $metricbeatzipurl -OutFile c:\temp\metricbeat.zip
#unzip
Expand-Archive -Path c:\temp\metricbeat.zip -DestinationPath c:\temp\Metricbeat
#copy to programfiles
Move-Item -Path c:\temp\Metricbeat -Destination 'C:\Program Files'
cd 'C:\Program Files\Metricbeat'
Invoke-Expression "& .\install-service-metricbeat.ps1"
Invoke-Item .\metricbeat.yml
Read-host "Configure metricbeat.yml then press enter..."
.\metricbeat.exe modules enable iis windows
.\metricbeat.exe setup -e
Start-Service metricbeat
Write-host "Metricbeat install script complete - check Kibana to confirm integration"