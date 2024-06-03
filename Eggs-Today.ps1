Clear-Host
Import-Module -Name "UMN-Google" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Set security protocol to TLS 1.2 to avoid TLS errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

############################## VARIABLES #################################
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
$endOfToday = ((Get-Date).AddDays(1)).ToString("yyyy-MM-ddThh:mm:ssZ")

$currDateTime = (Get-Date -Format yyyy-MM-dd)
$startDateTime = [datetime]"2024-03-02"

$daysSince = $(New-TimeSpan -Start $startDateTime -End $currDateTime).Days

########################## FUNCTION ############################################
function Get-AccessToken {
  # Google API Authorization
  $scope = "https://www.googleapis.com/auth/calendar"
  $certPath = "$PSScriptRoot\egg-counter-key.p12"
  $iss = 'egg-counter@egg-counter-418101.iam.gserviceaccount.com'
  $certPswd = 'notasecret'
  try {
    $accessToken = Get-GOAuthTokenService -scope $scope -certPath $certPath -certPswd $certPswd -iss $iss
    return $accessToken
  }
  catch {
    $err = $_.Exception
    $err | Select-Object -Property *
    "Response: "
    $err.Response
  }
  
}
function Get-StatData {
  param (
    [datetime]$dateTime
  )

  $accessToken = Get-AccessToken
  $advStats = [array[]]::new(7)
  $eggsPerDay = [int[]]::new(7)
  $numDays = [int[]]::new(7)
  $currStart = ($dateTime.ToString("yyyy-MM-ddT00:00:00Z"))
  $currEnd = ($dateTime.toString("yyyy-MM-ddT23:59:59Z"))
  $idx = $(New-TimeSpan -Start $currStart -End $(Get-Date -Format yyyy-MM-ddT00:00:00Z)).Days

  
  for ($i = 0; $i -lt $idx; $i++) {
    Write-Progress -Activity "Data Collection in Progress" -Status "$i% Complete:" -PercentComplete $i

    #Calendar to connect with
    $statsRequestUri = "https://www.googleapis.com/calendar/v3/calendars/0ed0cbe93c405a650e5c2f535fae9ff8e170fc3d917b717942bd8950037dff65@group.calendar.google.com/events/"

    #Get egg count from yesterday
    $statsEventsBody = @{"timeMin" = "$currStart"
      "timeMax"                    = "$currEnd"
      "maxEvents"                  = 15
    }
    $statsCalEvents = Invoke-RestMethod -Headers @{"Authorization" = "Bearer $accessToken" } `
      -Uri $statsRequestUri `
      -Method Get `
      -Body $statsEventsBody `
      -ContentType 'application/json'

    $count = 0
    foreach ($item in $($statsCalEvents.items)) {
      if (($item.summary).contains("`u{1F95A}")) {
        $count += 1
      }
    }

    $currDay = $dateTime.DayOfWeek
      
      switch ($currDay) {
        "Monday" { $eggsPerDay[0] += $count; $numDays[0]++ }
        "Tuesday" { $eggsPerDay[1] += $count; $numDays[1]++ }
        "Wednesday" { $eggsPerDay[2] += $count; $numDays[2]++ }
        "Thursday" { $eggsPerDay[3] += $count; $numDays[3]++ }
        "Friday" { $eggsPerDay[4] += $count; $numDays[4]++ }
        "Saturday" { $eggsPerDay[5] += $count; $numDays[5]++ }
        "Sunday" { $eggsPerDay[6] += $count; $numDays[6]++ }
        Default { Throw "something happened!!!" }
      }

    $dateTime = $dateTime.AddDays(1)
    $currStart = ($dateTime.ToString("yyyy-MM-ddT00:00:00Z"))
    $currEnd = ($dateTime.toString("yyyy-MM-ddT23:59:59Z"))
  }
  
  for ($i = 0; $i -lt $advStats.Count; $i++) {
    $advStats[$i] = @($eggsPerDay[$i], $numDays[$i])
  }
  
  return $advStats
}
function Get-AdvancedStats {
  param (
    [datetime]$dateTime
  )

  #collect data
  $statsArr = Get-StatData -dateTime $dateTime

  Clear-Host

  #Gui Creation and user input for egg count
  $statsForm = New-Object System.Windows.Forms.Form
  $statsForm.Text = 'Egg Counter Stats'
  $statsForm.Size = New-Object System.Drawing.Size(300, 300)
  $statsForm.StartPosition = 'CenterParent'

  $backButton = New-Object System.Windows.Forms.Button
  $backButton.Location = New-Object System.Drawing.Point(75, 175)
  $backButton.Size = New-Object System.Drawing.Size(75, 23)
  $backButton.Text = 'EXIT'
  $backButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $statsForm.AcceptButton = $backButton
  $statsForm.Controls.Add($backButton)

  $label = New-Object System.Windows.Forms.Label
  $label.Location = New-Object System.Drawing.Point(10, 0)
  $label.Size = New-Object System.Drawing.Size(280, 160)
  $label.Text = "DayOfWeek Total Avgerage

Monday:       $($statsArr[0][0])   $([math]::round($($statsArr[0][0])/$($statsArr[0][1]),2))
Tuesday:      $($statsArr[1][0])   $([math]::round($($statsArr[1][0])/$($statsArr[1][1]),2))
Wednesday: $($statsArr[2][0])   $([math]::round($($statsArr[2][0])/$($statsArr[2][1]),2))
Thursday:   $($statsArr[3][0])   $([math]::round($($statsArr[3][0])/$($statsArr[3][1]),2))
Friday:        $($statsArr[4][0])   $([math]::round($($statsArr[4][0])/$($statsArr[4][1]),2))
Saturday:   $($statsArr[5][0])   $([math]::round($($statsArr[5][0])/$($statsArr[5][1]),2))
Sunday:      $($statsArr[6][0])   $([math]::round($($statsArr[6][0])/$($statsArr[6][1]),2))
"
  $statsForm.Controls.Add($label)
  $statsForm.Topmost = $true

  $statsForm.Add_Shown({ $textBox.Select() })
  $statResult = $statsForm.ShowDialog()

  if ($statResult -eq [System.Windows.Forms.DialogResult]::OK) {
    $this.close
  }

  
}


############################ EXECUTION ##############################################
$accessToken = Get-AccessToken

#Calendar to connect with
$requestUri = "https://www.googleapis.com/calendar/v3/calendars/0ed0cbe93c405a650e5c2f535fae9ff8e170fc3d917b717942bd8950037dff65@group.calendar.google.com/events/"

#Get egg count from yesterday
$eventsBody = @{"timeMin" = "$yesterday"
  "timeMax"               = "$endOfToday"
  "maxEvents"             = 15
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

#get/create stats to be displyed
$dailyAvg = $currCount / $daysSince
$weeklyAvg = $currCount / ($daysSince / 7)
$monthlyAvg = $currCount / ($daysSince / 30)

#Gui Creation and user input for egg count
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Egg Counter'
$form.Size = New-Object System.Drawing.Size(300, 300)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75, 160)
$okButton.Size = New-Object System.Drawing.Size(75, 23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$statButton = New-Object System.Windows.Forms.Button
$statButton.Location = New-Object System.Drawing.Point(110, 183)
$statButton.Size = New-Object System.Drawing.Size(75, 23)
$statButton.Text = 'More Stats'
$form.Controls.Add($statButton)
$statButton.Add_Click({ Get-AdvancedStats -dateTime $startDateTime })

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150, 160)
$cancelButton.Size = New-Object System.Drawing.Size(75, 23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(280, 20)
$label.Text = 'How many Eggs to add?'
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

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 70)
$label.Size = New-Object System.Drawing.Size(280, 80)
$label.Text = "
Daily Egg Avg: $([math]::round($dailyAvg,2))
Weekly Egg Avg: $([math]::round($weeklyAvg,2))
Monthly Egg Avg: $([math]::round($monthlyAvg,2))"
$form.Controls.Add($label)
$form.Topmost = $true

$form.Add_Shown({ $textBox.Select() })
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
  $x = $textBox.Text
  [int]$newEggs = $x
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
  }
  else {
    Write-Host "`u{1F95A}$currEgg added. $($emojis | Get-Random)"
  }
  
  Start-Sleep -Milliseconds 500
  
}
