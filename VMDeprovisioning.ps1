#requires -version 4.0

#region DSC Resources
$DSCResources = ("xHyper-V","TrustedHostResource")

$InstalledResources = ((Get-DscResource).ModuleName | select -Unique)

foreach ($DSCResource in $DSCResources){
    If($DSCResource -notin $InstalledResources){
        Install-Module -Name $DSCResource -Force
    }
}


Configuration VMDeProvisioning{

    param(
        [string]$computername,
        [string[]]$vmnames,
        [string]$VHDFilePath,
        [string]$Domain,
        [string]$BatchName
    )    

    Import-DscResource -module xDismFeature, XHyper-V, TrustedHostResource

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

        $VMIP = ((Get-VM "$Domain-$VMName").NetworkAdapters).ipaddresses[0]

        TrustedHost "Remove $VMName IP from trusted host"{
            Ensure = 'Absent'
            Name = $VMIP
        }

        xVMHyperV "VMPath_$vmname"
        {
            Ensure          = 'Absent'
            Name            = "$Domain-$VMName"
            VhdPath         = (Join-Path "C:\VM\" ($Domain + "-$VMName" + ".vhd"))
            SwitchName      = 'ExternalVirtualSwitch'
            Path            = (Join-Path "C:\VM\" ($Domain + "-$VMName"))
            Generation      = 1
            StartupMemory   = 300mb
            MaximumMemory   = 512mb          
            ProcessorCount  = 1            
            State = 'Running'
            DependsOn       = "[TrustedHost]Remove $VMName IP from trusted host"
            WaitForIP = $True
            Notes = $batchname
        }

        File "VHDCopy_$VMName"{
            DependsOn = "[xVMHyperV]VMPath_$vmname"
            DestinationPath = (Join-Path "C:\VM\" ($Domain + "-$VMName" + ".vhd"))            
            Ensure = 'Absent'
            Type = 'File'            
        }
        File "VMPath_$VMName"{
            DependsOn = "[xVMHyperV]VMPath_$vmname"
            DestinationPath = (Join-Path "C:\VM\" ($Domain + "-$VMName"))
            Ensure = 'Absent'
            Type = 'Directory'
            Force = $True         
        }
    }    
}
#endregion

#region Configuration
$VMs = ("VM2","VM3","VM4") #VM Name will be $Domain-$VM
$Domain = "NY"
$MOFPath = "C:\Github\DSCResources\VMDeprovisioning"

$Params = @{
            Computername = $env:COMPUTERNAME
            OutputPath = $MOFPath
            VHDFIlePath = "C:\VM\Base\Nano-TP4.vhd"
            VMNames = $VMs
            Domain = $Domain
            BatchName = "DSCTest"
        }
#endregion

#region Process
VMDeProvisioning @params

Start-DscConfiguration $MOFPath -wait -Force
#endregion