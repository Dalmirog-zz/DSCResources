#requires -version 4.0



Configuration Myconfig{
    param(
        [string]$computername,
        [string[]]$vmnames,
        [string]$VHDFilePath
    )    

    Node $computername{
        File VHDIsPresent{
            Ensure = 'Present'
            DestinationPath = $VHDFilePath          
        }            
        
        foreach ($VMName in $VMNames){

        File "VHDCopy_$VMName"{
            DependsOn = "[File]VHDIsPresent"
            DestinationPath = (Join-Path "C:\VM\" ((Get-Item $VHDFilePath).BaseName + "_$VMName" + ".vhd"))
            SourcePath = $VHDFilePath
            Ensure = 'Present'
            Type = 'File'            
        }        
        
        }        
    }
}

myconfig -VHDFilePath "C:\VM\Base\Nano-TP4.vhd" -vmnames 1 -computername $env:COMPUTERNAME -OutputPath C:\Github\DSCResources\MYConfig

Start-DscConfiguration C:\github\DSCResources\MyConfig -Force -Wait