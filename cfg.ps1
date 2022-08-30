$username = 'johnny'

$password = 'Password1234!'

$pso = New-PSSessionOption -SkipCACheck

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force

$credentials = New-Object System.Management.Automation.PSCredential($username, $secpasswd)

$session = New-PSSession -ComputerName '20.168.117.17' -UseSSL -SessionOption $pso -Credential $credentials

$scrtipt = {
#cleaning up WebSite logs
Import-Module WebAdministration
foreach($website in $(Get-Website))  
{  
    
    $folder="$($website.logFile.directory)\W3SVC$($website.id)".replace("%SystemDrive%",$env:SystemDrive)  
     
    $files = Get-ChildItem $folder -Filter *.log 
  
    foreach($file in $files){  
        Remove-Item $file.FullName  
    }  
}  
#cleaning up apppool
$pool = Get-IISAppPool -Name "DefaultAppPool"
$pool.recycle()

import-module servermanager
add-windowsfeature web-server -includeallsubfeature
add-windowsfeature Web-Asp-Net45
add-windowsfeature NET-Framework-Features
$ipv4 = (Get-NetIPAddress | Where-Object {$_.AddressState -eq "Preferred" -and $_.InterfaceAlias -eq "Ethernet"}).IPAddress
Set-Content -Path "C:\inetpub\wwwroot\Default.html" -Value "This is the $ipv4 $($env:computername) !"
}


Invoke-Command -Session $session -ScriptBlock { $scrtipt } 
    
$session2 = New-PSSession -ComputerName '20.168.90.192' -UseSSL -SessionOption $pso -Credential $credentials

Invoke-Command -Session $session2 -ScriptBlock { $scrtipt } 
   
