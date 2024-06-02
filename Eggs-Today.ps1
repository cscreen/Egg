Clear-Host
Import-Module -Name "UMN-Google" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Set security protocol to TLS 1.2 to avoid TLS errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#set local vars
[int]$currCount = 0
[int]$newEggs = 0
[System.Collections.ArrayList]$emojis = @("`u{1F61C}", `
                                          "`u{1F61D}", `
                                          "`u{1F60F}", `
                                          "`u{1F631}", `
                                          "`u{1F635}", `
                                          "`u{1F60E}", `
                                          "`u{1F974}", `
                                          "`u{1FAE6}", `
                                          "`u{1F90C}", `
                                          "`u{1F485}", `
                                          "`u{1F92F}"
                                          )
                                          
$today = $(Get-Date -Format yyyy-MM-dd).ToString()
$yesterday = ((Get-Date).AddDays(-1)).ToString("yyyy-MM-ddT00:00:00Z")
$toDateTime = ((Get-Date).AddDays(1)).ToString("yyyy-MM-ddThh:mm:ssZ")

# Google API Authorization
$scope = "https://www.googleapis.com/auth/calendar"
$certPath = "$PSScriptRoot\egg-counter-key.p12"
$iss = 'egg-counter@egg-counter-418101.iam.gserviceaccount.com'
$certPswd = 'notasecret'
try {
  $accessToken = Get-GOAuthTokenService -scope $scope -certPath $certPath -certPswd $certPswd -iss $iss
}
catch {
  $err = $_.Exception
  $err | Select-Object -Property *
  "Response: "
  $err.Response
}

#Gui Creation and user input for egg count
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Data Entry Form'
$form.Size = New-Object System.Drawing.Size(300, 200)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75, 120)
$okButton.Size = New-Object System.Drawing.Size(75, 23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150, 120)
$cancelButton.Size = New-Object System.Drawing.Size(75, 23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(280, 20)
$label.Text = 'How many Eggs to add?:'
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 40)
$textBox.Size = New-Object System.Drawing.Size(260, 20)
$textBox.Add_TextChanged({
    if ($this.Text -match '[^0-9]') {
      $cursorPos = $this.SelectionStart
      $this.Text = $this.Text -replace '[^0-9]', ''
      # move the cursor to the end of the text:
      # $this.SelectionStart = $this.Text.Length

      # or leave the cursor where it was before the replace
      $this.SelectionStart = $cursorPos - 1
      $this.SelectionLength = 0
    }
  })
$form.Controls.Add($textBox)

$form.Topmost = $true

$form.Add_Shown({ $textBox.Select() })
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
  $x = $textBox.Text
  [int]$newEggs = $x
}

#Calendar to connect with
$requestUri = "https://www.googleapis.com/calendar/v3/calendars/0ed0cbe93c405a650e5c2f535fae9ff8e170fc3d917b717942bd8950037dff65@group.calendar.google.com/events/"

#Get egg count from yesterday
$eventsBody = @{"timeMin" = "$yesterday"
                "timeMax" = "$toDateTime"
                "maxEvents" = 15
}
$calEvents = Invoke-RestMethod -Headers @{"Authorization" = "Bearer $accessToken" } `
  -Uri $requestUri `
  -Method Get `
  -Body $eventsBody `
  -ContentType 'application/json'

foreach ($item in $($calEvents.items)) {
  if (($item.summary).contains("`u{1F95A}")) {
    $curr = $($item.summary).Replace("`u{1F95A}", "")

    if ($currCount -lt $curr) {
      $currCount = $curr
    }
  }
  
}

#loop through creating each all day egg count with emoji
for ($i = 0; $i -lt $newEggs; $i++) {
  $currEgg = $currCount + $i + 1
  #Event to create
  $body = @{
    "summary"      = "`u{1F95A}$currEgg"
    start          = @{"date" = "$today" }
    end            = @{"date" = "$today" }
    "transparency" = "transparent"
  }
  $json = $body | ConvertTo-Json
  $response = Invoke-RestMethod -Headers @{"Authorization" = "Bearer $accessToken" } `
    -Uri $requestUri `
    -Method Post `
    -Body $json `
    -ContentType 'application/json'

  if ($response.status -ne "confirmed") {
    Write-Host $response
    Read-Host -Prompt "Press Enter to exit"
    Exit-PSSession
  } else {
    Write-Host "`u{1F95A}$currEgg added. $($emojis | Get-Random)"
  }
  
  Start-Sleep -Milliseconds 500
  
}
