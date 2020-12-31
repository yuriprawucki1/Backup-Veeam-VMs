##################################################################
#                            Variáveis
##################################################################

# Nome das VMs que farão parte do backup separado por vírgula. (Variável obrigatória)
$VMNames = "SRV01","SRV02","SRV03"

# Nome do vCenter ou host standalone onde as VMs estão. (Variável obrigatória)
$HostName = "192.168.1.1"

# Diretório que o backup será gravado. Pode ser um caminho de rede.
$Directory = "\\192.168.1.2\Backup"

# Nível da compreesão do backup. Valores possíveis: 0 - None, 4 - Dedupe-friendly, 5 - Optimal, 6 - High, 9 - Extreme). (Variável Opcional)
$CompressionLevel = "5"

# Utilização da opção Quiesce durante o snapshot. Necessário VMware Tools instalado na VM. (Variável Opcional)
$EnableQuiescence = $False

# Encriptar o backup. (Variável Opcional)
$EnableEncryption = $True

# Senha para criptografar os arquivos. (Variável Opcional)
$EncryptionString = "C:\encrypt.txt"

# Retenção do backup. Valores: Never , Tonight, TomorrowNight, In3days, In1Week, In2Weeks, In1Month)
$Retention = "In2Week"

##################################################################
#                  Configuração de Notificação
##################################################################

# Habilitar notificação (Variável opcional)
$EnableNotification = $True

# Defina o nome do servidor SMTP
$SMTPServer = "smtp.gmail.com"

# Email De
$EmailFrom = "no-reply@email.com.br"

# Email Para
$EmailTo = "meu@email.com.br","meu2@email.com.br"

# Assunto
$EmailSubject = "SRV-BACKUP - Backup Veeam VMs"

##################################################################
#                   Formatação do Email 
##################################################################

$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$style = $style + "TD{border: 1px solid black; padding: 5px; }"
$style = $style + "</style>"

##################################################################
#            Fim das variáveis definidas pelo usuário
##################################################################

Asnp VeeamPSSnapin

$Server = Get-VBRServer -name $HostName
$MesssagyBody = @()

foreach ($VMName in $VMNames)
{
  $VM = Find-VBRViEntity -Name $VMName -Server $Server

# Senha do compartilhamento da pasta da rede
  $NetCreds = Get-VBRCredentials -Name "backup"
  
  If ($EnableEncryption)
  {
    $EncryptionKey = Add-VBREncryptionKey -Password (cat $EncryptionString | ConvertTo-SecureString)
    $ZIPSession = Start-VBRZip -Entity $VM -Folder $Directory -Compression $CompressionLevel -DisableQuiesce:(!$EnableQuiescence) -EncryptionKey $EncryptionKey -NetworkCredentials $NetCreds -AutoDelete $Retention
  }
  
  Else 
  {
    $ZIPSession = Start-VBRZip -Entity $VM -Folder $Directory -Compression $CompressionLevel -DisableQuiesce:(!$EnableQuiescence) -NetworkCredentials $NetCreds -AutoDelete $Retention
  }
  
  If ($EnableNotification) 
  {
    $TaskSessions = $ZIPSession.GetTaskSessions().logger.getlog().updatedrecords
    $FailedSessions =  $TaskSessions | where {$_.status -eq "EWarning" -or $_.Status -eq "EFailed"}
  
  if ($FailedSessions -ne $Null)
  {
    $MesssagyBody = $MesssagyBody + ($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={$FailedSessions.Title}})
  }
   
  Else
  {
    $MesssagyBody = $MesssagyBody + ($ZIPSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={($TaskSessions | sort creationtime -Descending | select -first 1).Title}})
  }
  
  }   
}
If ($EnableNotification)
{
$Message = New-Object System.Net.Mail.MailMessage $EmailFrom, $EmailTo
$Message.Subject = $EmailSubject
$Message.IsBodyHTML = $True
$message.Body = $MesssagyBody | ConvertTo-Html -head $style | Out-String
$SMTP = New-Object Net.Mail.SmtpClient($SMTPServer)
$SMTP.Send($Message)
}
