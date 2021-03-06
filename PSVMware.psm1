function ConvertTo-Template {
    <#
        .SYNOPSIS
        Function to retrieve the Network Configuration info of a vSphere host.
        .DESCRIPTION
        Function to retrieve the Network Configuration info of a vSphere host.
        .PARAMETER VMHost
        A vSphere ESXi Host object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> ConvertTo-Template -Template templateWS2016
        .EXAMPLE
        PS> Get-ContentLibraryItem templateWS2016 -ContentLibrary CL_WIN | ConvertTo-Template
        .NOTES
        NAME: Get-VMHostNetworkConfig
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('Template')]
        [ValidateNotNullOrEmpty()] #Ensure From is not equal to $null or ""
        [string]$Name,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] #Ensure From is not equal to $null or ""
        [string]$ContentLibrary,
        [parameter(Mandatory=$false)]
        [Alias('Datacenter')]
        [string]$DC_Name,
        [parameter(Mandatory=$false)]
        [Alias('VMHost')]
        [string]$VMHost_Name,
        [parameter(Mandatory=$false)]
        [Alias('Datastore')]
        [string]$Datastore_Name
    )
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        #Para poder tener control de errores necesitamos para la ejecucion cuando haya un error
        $ErrorActionPreference = 'Stop'
        #variable para controlar si todo ha ido bien o ha habido algun problema
        [bool]$status = $true
        #$cred = Get-Credential; New-VICredentialStoreItem -Host hostname.domain -User $cred.UserName -Password $cred.GetNetworkCredential().password
        $now = Get-Date
        $Datacenter = $null
        $VMHost = $null
        $Datastore = $null
    }
    process {
        try{
            #El Get-ContentLibraryItem no se puede hacer en el begin porque si $Name llega por pipe hasta el bloque process no tiene valor
            $Template = Get-ContentLibraryItem -Name $Name -ContentLibrary $ContentLibrary
            if ($DC_Name -eq ""){
                $Datacenter = Get-Datacenter | Get-Random
            }
            else {
                $Datacenter = Get-Datacenter -Name $DC_Name
            }
            if ($VMHost_Name -eq ""){
                $VMHost = Get-VMHost | Get-Random
            }
            else {        
                $VMHost = Get-VMHost -Name $VMHost_Name
            }    
            if ($Datastore_Name -eq ""){
                $Datastore = Get-Datastore | Get-Random
            }
            else {
                $Datastore = Get-Datastore -Name $Datastore_Name
            }
            $isTemplate = Get-Template $Name -ErrorAction SilentlyContinue
            if ($null -ne $isTemplate) {
                Write-Host -ForegroundColor Yellow "la plantilla existe en local hay que borrarla"
                Remove-Template $Name -DeletePermanently -Confirm:$false
            }
            $Cluster = $Datacenter | Get-Cluster | Get-Random
            # SPLATTING WITH HASH TABLE
            $HashArgumentsVM = @{
                Name = $Template.Name
                ContentLibraryItem = $Template
                ResourcePool = $Cluster
                VMHost = $VMHost
                Datastore = $Datastore
                DiskStorageFormat = 'Thin'
            }
            # Deploy VM
            $vm_obj = New-VM @HashArgumentsVM
            Set-VM $vm_obj -ToTemplate -Confirm:$false
        }
        catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.InvalidLogin]{
            Write-Host "Permission issue"
            $status = $false
        }
        catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException]{
            Write-Host "Cannot connect to vCenter Server"
            $status = $false
        }
        catch {
            write-host "Exception Type: $($PSItem.Exception.GetType().FullName)" -ForegroundColor Cyan
            write-host "Exception UnderlyingSystemType: $($PSItem.Exception.GetType().UnderlyingSystemType)" -ForegroundColor Cyan
            write-host "Exception Message: $($PSItem.Exception.Message)" -ForegroundColor Red
            $status = $false
        }
    }
    end {
        $later = Get-Date
        $nts = New-TimeSpan -Start $now -End $later
        Write-Host -ForegroundColor Green "La copia de la plantilla ha tardado: " $nts.ToString("d'.'hh':'mm':'ss")
        return $status
    }
    } #End Function ConvertTo-Template
    
    function Get-VMCustomizationSpec {
    <#
        .SYNOPSIS
        Function to retrieve info of Get-OSCustomizationSpec and Get-OSCustomizationNicMapping.
        .DESCRIPTION
        Function to retrieve info of Get-OSCustomizationSpec and Get-OSCustomizationNicMapping.
        .PARAMETER CProfile
        A vSphere OSCustomizationSpecImpl object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMCustomizationSpec -CProfile CP_Linux_Suse_12
        .EXAMPLE
        PS> Get-OSCustomizationSpec | Get-VMCustomizationSpec
        .NOTES
        NAME: Get-VMCustomizationSpec
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$CProfile
    )
    
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $CProfile_obj = @()
    }
    process {
        foreach ($Profile in $CProfile) {
            $Profile = Get-OSCustomizationSpec $Profile
            $ProfileNic = $Profile | Get-OSCustomizationNicMapping
            $CProfile_obj += [PSCustomObject]@{
                Name                = $Profile.Name
                Description         = $Profile.Description
                AutoLogonCount      = $Profile.AutoLogonCount
                ChangeSid           = $Profile.ChangeSid
                Type                = $Profile.Type
                OSType              = $Profile.OSType
                LastUpdate          = $Profile.LastUpdate
                Server              = $Profile.Server
                TimeZone            = $Profile.TimeZone
                Workgroup           = $Profile.Workgroup
                IPMode              = $ProfileNic.IPMode
                IPAddress           = $ProfileNic.IPAddress
                SubnetMask          = $ProfileNic.SubnetMask
                DefaultGateway      = $ProfileNic.DefaultGateway
                AlternateGateway    = $ProfileNic.AlternateGateway
                DnsServer           = $Profile.DnsServer
                DnsSuffix           = $Profile.DnsSuffix
                Domain              = $Profile.Domain
            }#EndPSCustomObject
        }	
    }
    end {
        return $CProfile_obj
    }
    }#End Function Get-VMCustomizationSpec
    
    function Get-VMConfig {
    <#
        .SYNOPSIS
        Function to retrieve Configuration info of a VM.
        .DESCRIPTION
        Function to retrieve Configuration info of a VM.
        .PARAMETER VM
        A vSphere VM object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMConfig -VM VM01, VM02
        .EXAMPLE
        PS> Get-VM VM01, VM02 | Get-VMConfig
        .NOTES
        NAME: Get-VMConfig
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$VM
    )
    
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $VMConfig_obj = @()
    }
    process {
        foreach ($VMName in $VM) {
            $VMName = Get-VM $VMName
            $VMDT = $VMName | Get-Datastore
            $vSwitch = $VMName | Get-VirtualSwitch
            $vPortGroup = $VMName | Get-VirtualPortGroup
            $VMDisks = $VMName | Get-HardDisk | select Parent, Name, StorageFormat, CapacityGB, Filename
            $VMView = $VMName | Get-View
            $VMConfig_obj += [PSCustomObject]@{
                Name                    = $VMName.Name
                PowerState              = $VMName.PowerState
                NumCpu                  = $VMName.NumCpu
                MemoryGB                = $VMName.MemoryGB
                MemoryHotAddEnabled     = $VMView.Config.MemoryHotAddEnabled
                CpuHotAddEnabled        = $VMView.Config.CpuHotAddEnabled
                CpuHotRemoveEnabled     = $VMView.Config.CpuHotRemoveEnabled
                MaxCpuUsage             = $VMView.Runtime.MaxCpuUsage
                MaxMemoryUsage          = $VMView.Runtime.MaxMemoryUsage
                OverallCpuUsage         = $VMView.Summary.QuickStats.OverallCpuUsage
                OverallCpuDemand        = $VMView.Summary.QuickStats.OverallCpuDemand
                GuestMemoryUsage        = $VMView.Summary.QuickStats.GuestMemoryUsage
                VMMemoryUsage           = $VMView.Summary.QuickStats.HostMemoryUsage
                Uptime                  = (New-TimeSpan -Seconds $VMView.Summary.QuickStats.UptimeSeconds).ToString("d'.'hh':'mm':'ss")
                VMHost                  = $VMName.VMHost
                UsedSpaceGB             = [math]::Round($VMName.UsedSpaceGB, 2)
                ProvisionedSpaceGB      = [math]::Round($VMName.ProvisionedSpaceGB, 2)
                CreateDate              = $VMName.CreateDate
                OSFullName              = $VMName.Guest.OSFullName
                "VMTools Version"       = $VMView.Config.Tools.ToolsVersion
                IPAddress               = $VMName.Guest.IPAddress
                Nics                    = $VMName.Guest.Nics
                Datastore_Name          = $VMDT.Name
                VirtualSwitch           = $vSwitch.Name
                vPortGroup              = $vPortGroup.Name
                VLanId                  = $vPortGroup.VLanId
                Disks					= $VMDisks
            }#EndPSCustomObject
        }	
    }
    end {
        return $VMConfig_obj
    }
    }#End Function Get-VMConfig
    
    function Get-VMHostCDPInfo {
    <#
        .SYNOPSIS
        Function to retrieve the information about the uplink Cisco switch and related configured physical switch ports with CDP.
        .DESCRIPTION
        Function to retrieve the information about the uplink Cisco switch and related configured physical switch ports with CDP.
        .PARAMETER VMHost
        A vSphere ESXi Host object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMHostCDPInfo -VMHost ESXi01, ESXi02
        .EXAMPLE
        PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostCDPInfo
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
        https://kb.vmware.com/s/article/1007069
        https://www.powershellgallery.com/packages/PowerCLITools/1.0.1/Content/Functions%5CGet-VMHostNetworkAdapterCDP.psm1
    #>  
    [CmdletBinding()][OutputType('System.Management.Automation.PSObject')]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$VMHost
    )
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $VMHostCDPinfo_obj = @()
    }
    process {
        try {
            foreach ($vHost in $VMHost) {
                $vHost = Get-VMHost $VMHost
                if ($vHost.ConnectionState -ne "Connected") {
                    Write-Output "Host $($vHost) state is not connected, skipping."
                }
                else {
                    $HostNetworkSystem = Get-View $vHost.ExtensionData.ConfigManager.NetworkSystem
                    $PNICs = $HostNetworkSystem.NetworkInfo.Pnic
                    foreach ($PNIC in $PNICs){
                        $PNicHintInfo = $HostNetworkSystem.QueryNetworkHint($PNIC.Device)
                        if ($PNicHintInfo.ConnectedSwitchPort){
                            $Connected = $true
                        }
                        else {
                            $Connected = $false
                        }
                        $VMHostCDPinfo_obj += [PSCustomObject]@{
                            VMHost = $vHost.Name
                            NIC = $PNIC.Device
                            Connected = $Connected
                            Switch = $PNicHintInfo.ConnectedSwitchPort.DevId
                            HardwarePlatform = $PNicHintInfo.ConnectedSwitchPort.HardwarePlatform
                            SoftwareVersion = $PNicHintInfo.ConnectedSwitchPort.SoftwareVersion
                            MangementAddress = $PNicHintInfo.ConnectedSwitchPort.MgmtAddr
                            PortId = $PNicHintInfo.ConnectedSwitchPort.PortId
                        }#EndPSCustomObject
                     }
                 }
            }    
        }
        catch [Exception] {
            throw "Unable to retreive CDP info"
        }
    }
    end {
        return $VMHostCDPinfo_obj
    }
    }#End Function Get-VMHostCDPInfo
    
    function Get-VMHostConfig {
    <#
        .SYNOPSIS
        Function to retrieve the Configuration info of a vSphere host.
        .DESCRIPTION
        Function to retrieve the Configuration info of a vSphere host.
        .PARAMETER VMHost
        A vSphere ESXi Host object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMHostConfig -VMHost ESXi01, ESXi02
        .EXAMPLE
        PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostConfig
        .NOTES
        NAME: Get-VMHostConfig
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$VMHost
    )
    
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $VMHostConfig_obj = @()
    }
    process {
        foreach ($vHost in $VMHost) {
            $vHost = Get-VMHost $VMHost
            $HostDTlist = $vHost | Get-Datastore
            $VMHostView = $vHost | Get-View
            $VMHostConfig_obj += [PSCustomObject]@{
                Name                    = $vHost.Name
                ConnectionState         = $vHost.ConnectionState
                PowerState              = $vHost.PowerState
                OverallStatus           = $VMHostView.Summary.OverallStatus
                Manufacturer            = $vHost.Manufacturer
                Model                   = $vHost.Model
                NumCpuSockets           = $VMHostView.Summary.Hardware.NumCpuPkgs
                NumCpuCores             = $vHost.NumCpu
                NumCpuThreads           = $VMHostView.Summary.Hardware.NumCpuThreads
                NumNics                 = $VMHostView.Summary.Hardware.NumNics
                NumHBAs                 = $VMHostView.Summary.Hardware.NumHBAs
                CpuTotalMhz             = $vHost.CpuTotalMhz
                CpuUsageMhz             = $vHost.CpuUsageMhz
                MemoryTotalGB           = [math]::Round($vHost.MemoryTotalGB, 2)
                MemoryUsageGB           = [math]::Round($vHost.MemoryUsageGB, 2)
                ProcessorType           = $vHost.ProcessorType
                HyperthreadingActive    = $vHost.HyperthreadingActive
                MaxEVCMode              = $vHost.MaxEVCMode
                Uptime                  = (New-TimeSpan -Seconds $VMHostView.Summary.QuickStats.Uptime).ToString("d'.'hh':'mm':'ss")            
                ManagementServerIp      = $VMHostView.Summary.ManagementServerIp
                VMSwapfileDatastore     = $vHost.VMSwapfileDatastore
                Datastores              = $HostDTlist
            }#EndPSCustomObject
        }
    }
    end {
        return $VMHostConfig_obj
    }
    }#End Function Get-VMHostConfig
    
    function Get-VMHostNetworkConfig {
    <#
        .SYNOPSIS
        Function to retrieve the Network Configuration info of a vSphere host.
        .DESCRIPTION
        Function to retrieve the Network Configuration info of a vSphere host.
        .PARAMETER VMHost
        A vSphere ESXi Host object
        .INPUTS
        System.Management.Automation.PSObject.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMHostNetworkConfig -VMHost ESXi01, ESXi02
        .EXAMPLE
        PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkConfig
        .NOTES
        NAME: Get-VMHostNetworkConfig
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$VMHost
    )
    
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $VMHostNetworkConfig_obj = @()
    }
    process {    
        foreach ($vHost in $VMHost) {
            $vHost = Get-VMHost $VMHost
            $vSwitches = $vHost | Get-VirtualSwitch -Standard
            $vDSwitches = $vHost | Get-VDSwitch
            #Standard Switches
            foreach ($vSwitch in $vSwitches) {
                $vPortGroups = $vSwitch | Get-VirtualPortGroup
                foreach ($vPortGroup in $vPortGroups){
                    $VMHostNetworkConfig_obj += [PSCustomObject]@{
                        VMHost          = $vHost
                        VirtualSwitch   = $vSwitch.Name
                        vPortGroup      = $vPortGroup.Name
                        Nic             = [string]$vSwitch.Nic
                        VLanId          = $vPortGroup.VLanId
                    }#EndPSCustomObject
                }
            }
            #Distributed Switches
            foreach ($vDSwitch in $vDSwitches) {
                $vDSwitch = Get-VDSwitch $vDSwitch
                $vDPortGroups = $vDSwitch | Get-VDPortgroup
                foreach ($vDPortGroup in $vDPortGroups){
                    $vDPorts = $vDPortGroup | Get-VDPort
                    $VMHostNetworkConfig_obj += [PSCustomObject]@{
                        VMHost          = $vHost
                        VirtualSwitch   = $vDSwitch.Name
                        vPortGroup      = $vDPortGroup.Name
                        VLanId          = $vDPortGroup.VlanConfiguration
                    }#EndPSCustomObject
                }
            }
        }
    }
    end {
        return $VMHostNetworkConfig_obj
    }
    } #End Function Get-VMHostNetworkConfig
    
    function Get-VMwareLicenses {
    <#
        .SYNOPSIS
        Function to retrieve all assigned licenses of a vSphere host and vCenter.
        .DESCRIPTION
        Function to retrieve all assigned licenses of a vSphere host and vCenter.
        .OUTPUTS
        System.Management.Automation.PSObject.
        .EXAMPLE
        PS> Get-VMwareLicenses
            vCenter           : VCSA01.contoso.com
            EntityDisplayName : EXS01.contoso.com
            LicenseKey        : XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
            LicenseName       : VMware vSphere 6 Standard
            ExpirationDate    : 01/01/2021 0:00:00
        .NOTES
        NAME: Get-VMwareLicenses
        AUTHOR: CarlosDZRZ
        .LINK
        https://code.vmware.com/web/tool/11.5.0/vmware-powercli
    #>  
    [CmdletBinding()]
    param (
    )
    
    begin {
        if ( -not (Get-Module  VMware.VimAutomation.Core)) {
            Import-Module VMware.VimAutomation.Core
        }
        if ($null -eq $global:DefaultVIServers.Name) {
            Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
            break
        }
        $AssignedLic_obj = @()
    }
    process {    
        foreach ($VCSA in $global:DefaultVIServers) {
            $licMgr = Get-View LicenseManager -Server $VCSA
            $licAssignmentMgr = Get-View -Id $licMgr.LicenseAssignmentManager -Server $VCSA
            $AssignedLics = $licAssignmentMgr.QueryAssignedLicenses($VCSA.InstanceUid)        
            foreach ($AssignedLic in $AssignedLics){
                $AssignedLic_obj += [PSCustomObject]@{
                    vCenter             = $VCSA.Name
                    EntityDisplayName   = $AssignedLic.EntityDisplayName
                    LicenseKey          = $AssignedLic.AssignedLIcense.LicenseKey
                    LicenseName         = $AssignedLic.AssignedLicense.Name
                    ExpirationDate      = $AssignedLic.Properties.value.Properties.where{$_.Key -eq 'expirationDate'}.Value
                }#EndPSCustomObject
            }
        }
    }
    end {
        return $AssignedLic_obj
    }
    } #End Function Get-VMwareLicenses