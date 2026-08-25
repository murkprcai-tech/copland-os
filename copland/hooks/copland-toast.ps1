# COPLAND OS -- windows-toast + notify-ton (ohne modul, WinRT direkt)
# aufruf: -Title "..." -Message "..." [-NoToast] [-NoSound]
param(
    [string]$Title   = 'COPLAND OS',
    [string]$Message = 'claude wartet auf input',
    [switch]$NoToast,
    [switch]$NoSound
)
$ErrorActionPreference = 'SilentlyContinue'

# ton
if (-not $NoSound) {
    $wav = Join-Path $env:USERPROFILE '.claude\copland-notify.wav'
    if (Test-Path $wav) {
        try { (New-Object System.Media.SoundPlayer $wav).PlaySync() } catch {}
    }
}

# toast
if (-not $NoToast) {
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $esc = { param($s) [System.Security.SecurityElement]::Escape($s) }
        $xml = @"
<toast duration="short">
  <visual>
    <binding template="ToastGeneric">
      <text>$(& $esc $Title)</text>
      <text>$(& $esc $Message)</text>
    </binding>
  </visual>
  <audio silent="true"/>
</toast>
"@
        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
        # AppId: powershell ist als app registriert, eigener name wuerde shortcut brauchen
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch {}
}
