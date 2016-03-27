#requires -version 4.0


$DSCResources = ("xHyper-V")

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
        [string]$Domain
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
        xVMHyperV "VMPath_$vmname"
        {
            Ensure          = 'Present'
            Name            = "$Domain-$VMName"
            VhdPath         = (Join-Path "C:\VM\" ($Domain + "-$VMName" + ".vhd"))
            SwitchName      = 'ExternalVirtualSwitch'
            Path            = (Join-Path "C:\VM\" ($Domain + "-$VMName"))
            Generation      = 1
            StartupMemory   = 512mb
            MaximumMemory   = 512mb          
            ProcessorCount  = 1
            State = 'Running'
            DependsOn       = "[File]VMPath_$VMName",'[xVMSwitch]ExternalSwitch'
        }
              
        
    }    
}

$Params = @{
            Computername = $env:COMPUTERNAME
            OutputPath = "C:\Github\DSCResources\FeaturesTest"
            VHDFIlePath = "C:\VM\Base\Nano-TP4.vhd"
            VMNames = ("VM1","VM2")
            Domain = "NY"

        }

VMprovisioning @params

Start-DscConfiguration C:\github\DSCResources\FeaturesTest -wait -Force