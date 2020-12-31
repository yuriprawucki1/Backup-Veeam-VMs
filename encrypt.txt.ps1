$SecurePassword = Read-Host -Prompt "Enter password" -AsSecureString

$SecurePassword | ConvertFrom-SecureString >> “C:\encrypt.txt”

Add-VBREncryptionKey -Password $securepassword -Description "Veeam Administrator"
