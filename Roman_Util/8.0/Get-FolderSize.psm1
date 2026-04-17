function Get-FolderSize {
    # version 2 2026-03-19
    param ($folder = '.')
    $folder = (get-item $folder).ResolvedTarget
    $objFSO = New-Object -com  Scripting.FileSystemObject
    "{0:N2}" -f (($objFSO.GetFolder("$folder").Size) / 1MB) + " MB"
}