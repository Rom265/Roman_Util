Function Get-ModuleCommand {
    <#
    .SYNOPSIS
    Get commands that are presented by one or more modules.
     
    .DESCRIPTION
    Get commands that are presented by one or more modules. By default, only the command from the highest version of the module is returned. If you specify the All parameter, commands from all versions of the module are returned.
    
    .NOTES
    Script: Get-ModuleCommand.ps1
    Author: Roman Revell
    tested on PowerShell 7.4.13
    
    History: 
    version 1    2026-03-20
    
    .PARAMETER ModuleName
    Name of the module as processed by Get-Command. You can use a wildcard (*).
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $ModuleName
    )
    $CommandObject = Get-Command -Module $ModuleName
    $FinalList = $CommandObject | Sort-Object Name, Version -Descending | Group-Object Name | ForEach-Object {
        $_.Group | Select-Object -First 1
    }

    $FinalList | Sort-Object ModuleName, Name
}