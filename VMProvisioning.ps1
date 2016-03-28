#requires -version 4.0

#region DSC Resources
$DSCResources = ("xHyper-V","TrustedHostResource","XSmbShare")

$InstalledResources = ((Get-DscResource).ModuleName | select -Unique)

foreach ($DSCResource in $DSCResources){
    If($DSCResource -notin $InstalledResources){
        Install-Module -Name $DSCResource -Force
    }
}


Configuration VMProvisioning{

    param(
        [string]$computername,
        [string[]]$vmnames,
        [string]$VHDFilePath,
        [string]$Domain,
        [string]$BatchName
    )    

    Import-DscResource -module xDismFeature, XHyper-V, TrustedHostResource,xSmbShare

    File "Create Share Folder"{
        Ensure = 'Present'
        DestinationPath = "c:\Share"
        Type = "Directory"
    }
    xSmbShare "Adding new host"
    {            
        Ensure = 'present'
        Path = "c:\share"           
        DependsOn = "[File]Create Share Folder"
        Name = "c"
    }   

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
    
    File BaseVHDIsPresent{
            Ensure = 'Present'
            DestinationPath = $VHDFilePath          
    }
                
        
    foreach ($VMName in $VMNames){

        File "VHDCopy_$VMName"{
            DependsOn = "[File]BaseVHDIsPresent"
            DestinationPath = (Join-Path "C:\VM\" ($Domain + "-$VMName" + ".vhd"))
            SourcePath = $VHDFilePath
            Ensure = 'Present'
            Type = 'File'            
        }
        File "VMPath_$VMName"{
            DependsOn = "[File]VHDCopy_$VMName"
            DestinationPath = (Join-Path "C:\VM\" ($Domain + "-$VMName"))
            Ensure = 'Present'
            Type = 'Directory'            
        }
        xVMHyperV "VMCreate_$vmname"
        {
            Ensure          = 'Present'
            Name            = "$Domain-$VMName"
            VhdPath         = (Join-Path "C:\VM\" ($Domain + "-$VMName" + ".vhd"))
            SwitchName      = 'ExternalVirtualSwitch'
            Path            = (Join-Path "C:\VM\" ($Domain + "-$VMName"))
            Generation      = 1
            StartupMemory   = 128mb
            MaximumMemory   = 512mb          
            ProcessorCount  = 1            
            State = 'Running'
            DependsOn       = "[File]VMPath_$VMName",'[xVMSwitch]ExternalSwitch'
            WaitForIP = $True
            Notes = $batchname
        }             
        
    }    
}

Configuration VMConfiguration{
    param(
        [string]$computername,
        [string[]]$vmnames,
        [string]$Domain        
    )
    Import-DscResource -module TrustedHostResource

    foreach ($VMName in $vmnames){
        TrustedHost "Add $VMName IP to trusted host"{
            Ensure = 'Present'
            Name = ((Get-VM "$Domain-$VMName").NetworkAdapters).ipaddresses[0]
        }
    }
}
#endregion

#region Configuration

$VMs = ("VM1") #VM Name will be $Domain-$VM
$Domain = "NY"

$MOFPath = @{Provisioning = "C:\Github\DSCResources\VMProvisioning"
            Configuration = "C:\Github\DSCResources\VMConfiguration"
            }

$ProvisioningParams = @{
            Computername = $env:COMPUTERNAME
            OutputPath = $MOFPath.Provisioning
            VHDFIlePath = "C:\VM\Base\Nano-TP4.vhd"
            VMNames = $VMs
            Domain = $Domain
            BatchName = "DSCTest"
        }
$ConfigurationParams = @{
            Computername = $env:COMPUTERNAME
            OutputPath = $MOFPath.Configuration
            VMNames = $VMs
            Domain = $Domain            
        }
#endregion

#region Process
VMprovisioning @Provisioningparams

Start-DscConfiguration $MOFPath.Provisioning -wait -Force

VMConfiguration @Configurationparams

Start-DscConfiguration $MOFPath.Configuration -wait -Force
#endregion