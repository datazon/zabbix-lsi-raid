<#
    .VERSION
    0.1
    
    .SYNOPSIS
    Script with LLD support for getting data from LSI RAID Controller to Zabbix monitoring system.

    .DESCRIPTION
    The script may generate LLD data for LSI RAID Controllers, Logical Drives, Physical Drives.

    .NOTES
	Author: Florian Schermer
	Email: florian.schermer@datazon.de
	Github: https://github.com/datazon/zabbix-lsi-raid
#>

Param (
[switch]$version = $false,
[ValidateSet("lld","health")][Parameter(Position=0, Mandatory=$True)][string]$action,
[ValidateSet("ad","ld","pd","bt")][Parameter(Position=1, Mandatory=$True)][string]$part,
[string][Parameter(Position=2)]$ctrlid,
[string][Parameter(Position=3)]$partid
)

$jsondata = C:\zabbix\tools\StorCli64.exe /c0 show all j | Out-String | ConvertFrom-Json

function LLDControllers(){
    foreach($controller in $jsondata.Controllers){
        $ctrl_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#CTRL.MODEL}}":"{1}","{{#CTRL.SN}}":"{2}"}},',$controller.'Response Data'.Basics.Controller,$controller.'Response Data'.Basics.Model, $controller.'Response Data'.Basics.'Serial Number')
        $ctrl_json += $ctrl_info
    }
    $lld_data = '{"data":[' + $($ctrl_json -replace ',$') + ']}'
    return $lld_data
}

function LLDBattery(){
    foreach($controller in $jsondata.Controllers){
        $ctrl_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#CTRL.BATTERY}}":"{1}"}},',$controller.'Response Data'.Basics.Controller,$controller.'Response Data'.'Supported Adapter Operations'.'BBU ')
        $ctrl_json += $ctrl_info
    }
    $lld_data = '{"data":[' + $($ctrl_json -replace ',$') + ']}'
    return $lld_data
}

function LLDLogicalDrives(){
    foreach($controller in $jsondata.Controllers){
        foreach($obj in $controller.'Response Data'.'VD LIST'){
            $ld_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#LD.ID}}":"{1}","{{#LD.NAME}}":"{2}","{{#LD.RAID}}":"{3}"}},',$controller.'Response Data'.Basics.Controller,$obj.'DG/VD', $obj.Name,$obj.State)
            $ld_json += $ld_info
        }
    $lld_data = '{"data":[' + $($ld_json -replace ',$') + ']}'
    return $lld_data
    }
}

function LLDPhysicalDrives(){
    foreach($controller in $jsondata.Controllers){
        foreach($obj in $controller.'Response Data'.'PD LIST'){
            $pd_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#PD.ID}}":"{1}"}},',$controller.'Response Data'.Basics.Controller,$obj.DID)
            $pd_json += $pd_info            
        }
    $lld_data = '{"data":[' + $($pd_json -replace ',$') + ']}'
    return $lld_data
    }
}

function GetControllerStatus()
{
    Param (
        [ValidateSet("main","battery","temperature")][string]$ctrl_part
    )
    
    switch($ctrl_part){
        "main" {
            $ctrl_status = $jsondata.Controllers[$ctrlid].'Response Data'.Status.'Controller Status'
        }
        "battery" {
            $ctrl_status = $jsondata.Controllers[0].'Response Data'.Status.'BBU Status'
        }
        "temperature" {
            $ctrl_status = $jsondata.Controllers[0].'Response Data'.HwCfg.'ROC temperature(Degree Celsius)'
            # if empty, take temperature from BBU
			if ($ctrl_status -eq $null){
			$ctrl_status = $jsondata.Controllers[0].'Response Data'.'BBU_Info'.'Temp'
			# del C
			$ctrl_status = $ctrl_status -replace "C", ""
			}
        }
    }
    return $ctrl_status
}

function GetLogicalDriveStatus(){
    foreach($obj in $jsondata.Controllers[$ctrlid].'Response Data'.'VD LIST'){
        if ($obj.'DG/VD' -eq $partid){
            return $obj.state
        }
    }
}

function  GetPhysicalDriveStatus(){
    foreach($obj in $jsondata.Controllers[$ctrlid].'Response Data'.'PD LIST'){
        if ($obj.'DID' -eq $partid){
            return  $obj.state
        }
    }
}

switch($action){
    "lld" {
        switch($part){
            "ad" { write-host $(LLDControllers) }
            "ld" { write-host $(LLDLogicalDrives)}
            "pd" { write-host $(LLDPhysicalDrives)}
            "bt" { write-host $(LLDBattery)}
        }
    }
    "health" {
        switch($part) {
            "ad" { write-host $(GetControllerStatus -ctrl_part $partid) }
            "ld" { write-host $(GetLogicalDriveStatus)}
            "pd" { write-host $(GetPhysicalDriveStatus)  }
        }
    }
    default {Write-Host "ERROR: Wrong argument: use 'lld' or 'health'"}
}