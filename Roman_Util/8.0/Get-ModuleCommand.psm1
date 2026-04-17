Function Get-ModuleCommand {
    <#
    .SYNOPSIS
    Get commands that are presented by one or more modules.
     
    .DESCRIPTION
    Get commands that are presented by one or more modules. By default, only the command from the highest version of the module is returned. If you specify the All parameter, commands from all versions of the module are returned.

    Note: this function can not *correctly* return itself in the output.
    
    .NOTES
    Script: Get-ModuleCommand.ps1
    Author: Roman Revell
    tested on PowerShell 7.4.13
    
    History: 
    version 2    2026-03-21 Make the output show the command name and alias on the same line so that it is clear that they are the same command.
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
    $CommandObject.Source | Sort-Object -Unique | ForEach-Object {
        if (!($_ -eq "Roman_Util")) {
            # Don't import Roman_Util because it would cause a recursive loop since this function is in that module and running this function means that that module has already been imported anyway.
            Import-Module $_ -DisableNameChecking
        }
    }
    $LatestVersion = $CommandObject | Sort-Object Name, Version -Descending | Group-Object Name | ForEach-Object {
        $_.Group | Select-Object -First 1
    }
    
    Foreach ($Command in $LatestVersion) {
        if ($Command.CommandType -eq 'Alias') {
            #Get-Command $Command.Name | Out-Null
            $ResolvedCommand = Get-Alias $Command.Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ResolvedCommand
            if ($ResolvedCommand) {
                Write-Verbose "Adding alias $($Command.Name) to command $($ResolvedCommand.Name)"
                $LatestVersion | Where-Object Name -eq $ResolvedCommand.Name | Add-Member -MemberType NoteProperty -Name Alias -Value $Command.Name
            }
        }
    }
    $FinalList = $LatestVersion | Where-Object CommandType -ne 'Alias'
    $FinalList | Select-Object @{Name = 'Module'; Expression = { $_.Source } }, Name, Alias, Version | Sort-Object Module, Name
}