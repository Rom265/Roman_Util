function Get-CredentialWithPrompt {
    # version 1 2026-03-19

    if (Ask-Question -Title "Credential needed" -Message "Would you like to use the current user ($($env:USERDOMAIN)\$($env:USERNAME))?"){
        $userId = "$($env:USERDOMAIN)\$($env:USERNAME)"
        Write-Host
    }
    else {
        Write-Host
        $userId = Read-Host "Enter user ID"
    }
    $password = Read-Host "Enter password" -AsSecureString
    new-object System.Management.Automation.PSCredential($userId, $password)
}