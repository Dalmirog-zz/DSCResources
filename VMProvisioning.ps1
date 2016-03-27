#requires -version 4.0


#Key-Value pairs to make sure the modules needed are installed
#Rigth hand side is the DSC resource and left side the module that contains the resource
#i.e - If the script needs the DSC resource XVMSwitch , which is part of the module xHyper-V, add an entry saying "XVMSwitch" = "XHyper-V"
$DSCResources = @{"xVMHyperV" = "xHyper-V"
                    "xVMSwitch" = "xHyper-V"
                    "xDismFeature" = "xDismFeature"
                }

foreach ($DSCResource in $DSCResources.GetEnumerator()){
    If(!(Get-DscResource -Name $DSCResource.Name)){
        Install-Module -Name $DSCResource.Value -Force
    }
}


Configuration VMProvisioning{

    param(
        [string]$computername,
        [string[]]$vmnames,
        [string]$VHDFilePath
    )    

    Import-DscResource -module xDismFeature, XHyper-V

    xDismFeature HyperV
    {
        Ensure = 'Present'
        Name   = 'Microsoft-Hyper-V-All'       
    }
    xDismFeature VMConnect
    {
        Ensure = 'Present'
        Name   = 'Microsoft-Hyper-V-Management-Clients'
        DependsOn =  '[xDismFeature]HyperV'
    }
    xVMSwitch ExternalSwitch
    {
        Ensure         = 'Present'
        Name           = 'ExternalVirtualSwitch'
        Type           = 'External'
        NetAdapterName = 'wi-fi'
        AllowManagementOS = $True
        DependsOn =  '[xDismFeature]HyperV'
    }
    
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

VMprovisioning -computername $env:COMPUTERNAME -OutputPath C:\Github\DSCResources\FeaturesTest

Start-DscConfiguration C:\github\DSCResources\FeaturesTest -wait -Force