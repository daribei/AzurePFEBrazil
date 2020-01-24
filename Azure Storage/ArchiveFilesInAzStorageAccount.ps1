#region GlobalVariables
# Set global variables
$outOfBandwidth = 0
$currentUsedBandwidthMb = 0
$currentNumberOfAzCopyThreads = 0
[System.Collections.ArrayList]$runningThreads = @()
$azCopylogLevel = "WARNING" #Available log levels are: NONE, DEBUG, INFO, WARNING, ERROR, PANIC, and FATAL.
#$env:https_proxy = "IPAddr:Port"

# Set AzCopy path
$azcopyPath = "C:\AZCopy_Path"
Set-Location $azcopyPath
$OutputFile = "$azcopyPath\FilesToCopy_$(Get-Date -f MMMM).csv"
$AzureFiles = "$azcopyPath\AzureBlobs.txt"

# Set Storage Account information
$storageAccountName = "stgName"
$storageAccountContainer = "stgContainerName"
$storageAccountSAS = "<SASKey>"
#endregion GlobalVariables

#region Functions

# Write an Event on Event Log
function LogEvent ([string]$message, [int]$eventId) {
    Write-EventLog -LogName AzCopyEvents -Source AzCopy -EntryType Information -EventId $eventId -Message $message
}
# Create CSV with files to be copied
function Format-CopyFilesCSV($files) {
    if (Test-Path -Path $OutputFile) {
        $logmessage = "CSV file for this month already exists."
        LogEvent $logmessage 350
    }
    else {
        $logmessage = "Starting CSV file creation"
        LogEvent $logmessage 300

        foreach ($file in $files) {
        
            $directory = Get-FileDirectory([string]$file)
            $allFiles = New-Object -TypeName psobject
            $allFiles | Add-Member NoteProperty Directory $directory -Force
            $allFiles | Add-Member NoteProperty File $file -Force
            $allFiles | Add-Member NoteProperty Status "0" -Force
            $allFiles | Add-Member NoteProperty ProcessId $null -Force
            $allFiles | Add-Member NoteProperty Bandwidth 0 -Force
            $allFiles | Export-Csv $OutputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ","
        }
        $logmessage = "Finishing CSV file creation"
        LogEvent $logmessage 300
    }
}

# Get SQL Instance using file Directory
function Get-FileDirectory ($file) {
    $file = $file.Split("\")[$file.Count - 2]
    return $file
}

# Define upload bandwidth
function Get-AvailableBandwidth($fileName) {
    if ((Get-Date).DayOfWeek -eq "Thursday" -and ((Get-date).Hour -ge 22 -or (Get-Date).Hour -lt 4)) {
        $bandwidthMb = 4000 - $currentUsedBandwidthMb
    }
    elseif ((Get-date).DayOfWeek -eq "Saturday" -or (Get-Date).DayOfWeek -eq "Sunday" -and ((Get-Date).Hour -ge 20 -or (Get-Date).Hour -lt 5)) {
        $bandwidthMb = 4000 - $currentUsedBandwidthMb
    }
    elseif ((Get-date).DayOfWeek -eq "Saturday" -or (Get-Date).DayOfWeek -eq "Sunday" -and ((Get-Date).Hour -lt 20 -or (Get-Date).Hour -ge 5)) {
        $bandwidthMb = 3000 - $currentUsedBandwidthMb
    }
    elseif ((Get-date).Hour -ge 20 -or (Get-Date).Hour -lt 4) {
        $bandwidthMb = 4000 - $currentUsedBandwidthMb
    }
    elseif ((Get-date).Hour -ge 4 -and (Get-Date).Hour -lt 20) {
        $bandwidthMb = 500 - $currentUsedBandwidthMb
    }

    if ($bandwidthMb -lt 0) {
        $bandwidthMb = 0
    }

    return $bandwidthMb
}
#endregion Functions

#region GettingArchivingFiles
# Get backup disks 
# TODO: Use TestPath to get all Disks with "SAJJUD" directory and eliminate the "Get backup disks" code
$availableDisks = Get-WmiObject Win32_LogicalDisk
$backupDisks = @()
foreach ($availableDisk in $availableDisks) {
    if ($availableDisk.DeviceID -ne "C:" -and $availableDisk.DeviceID -ne "D:") {
        $backupDisks += $availableDisk.DeviceID 
    }

}

# Get backup directories
$backupDirectories = @()
foreach ($backupDisk in $backupDisks) {
    $backupDirectories += (Get-ChildItem "$backupDisk\SAJJUD" -Recurse | ? { $_.PSIsContainer }).FullName
}

# Get backup files
$backupFiles = @()
foreach ($backupDirectory in $backupDirectories) {
    $backupFilesObjects = $null
    $backupFilesObjects = Get-ChildItem -Path $backupDirectory -Recurse -Include *.bak
    foreach ($backupFilesObj in $backupFilesObjects) {
        $backupFiles += $backupDirectory + '\' + $backupFilesObj.Name
    }
}
#endregion GettingArchivingFiles

#region Format CSV file
Format-CopyFilesCSV($backupFiles)

$input = Import-CSV -Path $OutputFile -Delimiter ','

# Get all files in Azure
$context = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $storageAccountSAS
$blobs = Get-AzStorageContainer -Name $storageAccountContainer -Context $context | Get-AzStorageBlob

$azureFilesNames = @()
foreach ($blob in $blobs){
    $name = $blob.Name.Split("/")
    $name = $name[$name.Count-1]
    $azureFilesNames += $name    
}

$azureFilesNames | Out-File $AzureFiles

# Change the status to 2 of all files already on Azure and
# Change the status to 0 of all files that are not in Azure and that have status 1 or 2.
$azureFilesNames = Get-Content $AzureFiles -Raw
$row = $null

foreach ($row in $input)
{
    $name = $row.File.Split('\')
    $name = $name[$name.Count-1]
    $status = $row.Status

    if (-not $azureFilesNames.Contains($name) -and $status -ne "0"){
      
    $row.Status = 0

    $input | Export-Csv $OutputFile -nti
    }

    if ($azureFilesNames.Contains($name) -and $status -ne "2"){
      
    $row.Status = 2

    $input | Export-Csv $OutputFile -nti
    }
}
#endregion format CSV file

$row = $null
$i = 0

#region Main
# Send files to Azure Storage Account
foreach ($row in $input) {
    # File counter
    $i++
    $file = $row.File
    $directory = $row.Directory
    $destination = "https://$storageAccountName.blob.core.windows.net/$storageAccountContainer/$directory/$storageAccountSAS"

    # Get name of file
    if ($row.Status -ne 0) {
        if ($row.Status -eq 2) {
            Write-Host "Arquivo " $row.File " ja esta no Azure."
            $logmessage = "File " + $row.File + " is already on Azure."
            LogEvent $logmessage 200
        }

        elseif ($row.Status -eq "1") {
            Write-Host "Arquivo " $row.File " ja executado, porem nao encontrado.`nAtualize o arquivo 'AzureBlobs.txt' com 'GetUploadedFiles.ps1' e execute o script novamente."
            $logmessage = "File " + $row.File + " already executed, but not found on Azure.`nUpdate file 'AzureBlobs.txt' with 'GetUploadedFiles.ps1' and run the script again."
            LogEvent $logmessage 100
        }
    }
    else {
        do {
            # Get available bandwidth and store on variable
            $availableBandwidthMb = Get-AvailableBandwidth($row.File)

            # Defining bandwidth to be used - based on available bandwidth (trying to balance bandwidth with 2 files)
            # Case available bandwidth is 500Mbps, 1 file will be sent using entire bandwidth
            if ($availableBandwidthMb -ge 3000) {
                $useBandwidthMb = $availableBandwidthMb / 2
            }
            elseif ($availableBandwidthMb -ge 2000 -and $availableBandwidthMb -lt 3000) {
                $useBandwidthMb = 2000
            }
            else {
                $useBandwidthMb = $availableBandwidthMb
            }
    
            # Controls current used bandwidth
            $currentUsedBandwidthMb += $useBandwidthMb

            Write-Host "Banda disponivel: " $availableBandwidthMb
            Write-Host "Banda a ser usada: " $useBandwidthMb
            Write-Host "Limite de banda atingido? 0=Nao 1=Sim " $outOfBandwidth
            
            $logmessage = "File: " + $row.File + ".`nAvailable Bandwidth: $availableBandwidthMb .`nBandwidth to be used on this file: $useBandwidthMb.`n`nIs the bandwidth limit reached? (0=No, 1=Yes): $outOfBandwidth"
            LogEvent $logmessage 0
             
            # Sending file using defined bandwidth or, case available bandwidth is less 
            #     than 1000Gbps, putting process in Sleep before test available bandwidth again
            if ($availableBandwidthMb -ge 500) {
                $outOfBandwidth = 0
                Write-Output "Enviando arquivo $i ($file) usando $useBandwidthMb Mbits"
                $logmessage = "Preparing to send file " + $row.File + " using " + $useBandwidthMb + " Mbps."
                LogEvent $logmessage 0

                # Increment control of AzCopy threads
                $currentNumberOfAzCopyThreads++

                ### TODO: Change Process to AzCopy - using an Start-Sleep for test purposes
                # Run AzCopy with pre-defined controls
                $argument = "copy `"$file`" `"$destination`" --cap-mbps `"$useBandwidthMb`" --log-level `"$azCopylogLevel`""
                $processControl = (Start-Process $azcopyPath\azcopy.exe -argument $argument -PassThru).Id
                Write-Output "Arquivo enviado. PID: $processControl"

                $logmessage = "File: " + $row.File + " being uploaded.`nUsing Bandwidth: $useBandwidthMb.`nPID: $processControl.`n"
                LogEvent $logmessage 0

                # Prepare to write the values on CSV file for control
                # Writing PID, Status = 1 and Bandwidth
                $row.ProcessId = $processControl
                $row.Status = 1
                $row.Bandwidth = $useBandwidthMb
                
                # Writing values on CSV
                $input | Export-Csv $OutputFile -nti

                #### TODO: Write PID on CSV file
                #### TODO: Write UsedBandwidth on CSV file
                #### TODO: Alternative using multivalue array
                [string]$aux = [string]$processControl + "|" + [string]$useBandwidthMb + "|" + [string]$row.File
                $runningThreads += $aux

                Write-Output "Banda total usada: $currentUsedBandwidthMb"
                Write-Output "Total de arquivos sendo transferidos: $currentNumberOfAzCopyThreads"
                Write-Host "Limite de banda atingido? 0=Nao 1=Sim " $outOfBandwidth
                Write-Output ""

                $logmessage = "Total used bandwidth: $currentUsedBandwidthMb.`nTotal file being sent: $currentNumberOfAzCopyThreads.`n`nIs the bandwidth limit reached? (0=No, 1=Yes): $outOfBandwidth"
                LogEvent $logmessage 0


                Start-Sleep -Seconds 5
            }
            # Enter in a wait state while Available Bandwidth is less than 1000 Gbps
            else {
                $outOfBandwidth = 1
                Write-Output ""
                (Get-Date).DateTime
                Write-Output "Arquivo $i em espera"
                Write-Output "Testar processos de AzCopy"
                Write-Host "Limite de banda atingido? 0=Nao 1=Sim $outOfBandwidth"

                $logmessage = "File $i : " + $row.File + " in wait.`nTesting current running AzCopy processes.`n`nIs the bandwidth limit reached? (0=No, 1=Yes): $outOfBandwidth"
                LogEvent $logmessage 0


                # Test if AzCopy threads are still running
                for ($t = 0; $t -lt $runningThreads.Count; $t++) {
                    $thread = $runningThreads[$t].Split('|')
                    Start-Sleep -Seconds 2
                    $processid = $thread[0]
                    $band = $thread[1]
                    $filepath = $thread[2]
                    if (Get-Process -Id $processid -ErrorAction SilentlyContinue) {
                        Write-Output "Processo $processid existe e usa $band Gbps de banda para transferir arquivo $filepath." 
                        $logmessage = "Process $processid  still running and using $band Mbps bandwidth to transfer $filepath."
                        LogEvent $logmessage 1
                    }
                    else {
                        Write-Output "Processo $processid terminou de transferir arquivo $filepath , liberando $band Mbits de banda"
                        $currentUsedBandwidthMb = $currentUsedBandwidthMb - [int]$band
                        Write-Output "Banda disponível $availableBandwidthMb"
                        $runningThreads.RemoveAt($t)
                        $currentNumberOfAzCopyThreads = $currentNumberOfAzCopyThreads - 1

                        $logmessage = "Process $processid has finished, releasing $band Mbps bandwidth"
                        LogEvent $logmessage 200

                        $blob = $filepath.Split('\')
                        $blob = $blob[$blob.Count - 1]
                        Add-Content $AzureFiles $blob
                        $logmessage = "Writing blob to file $AzureFiles."
                        LogEvent $logmessage 200

                    }
                }
                Start-Sleep -Seconds 60
            }
        }until($outOfBandwidth -eq 0)
    }

    Write-Host "Linha: $i | Banda: $availableBandwidthMb | Banda Usada: $currentUsedBandwidthMb"
    Write-Output ""
}

#endregion Main