Clear-Host
Import-Module -Name "UMN-Google" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Set security protocol to TLS 1.2 to avoid TLS errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

############################## VARIABLES #################################
#set local vars
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
$weeksSince = $daysSince / 7
$monthsSince = $daysSince / 30

#Calendar to connect with
$requestUri = "https://www.googleapis.com/calendar/v3/calendars/0ed0cbe93c405a650e5c2f535fae9ff8e170fc3d917b717942bd8950037dff65@group.calendar.google.com/events/"

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
$accessToken = Get-AccessToken

function Get-YesterdayEggs {
  param (
    [string]$start,
    [String]$end
  )


  
  [int]$currCount = 0

  #Get egg count from yesterday
  $eventsBody = @{"timeMin" = "$start"
    "timeMax"               = "$end"
    "maxEvents"             = 15
    "singleEvents"               = "$true"
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
  return $currCount
}

function Add-NewEggs {
  param (
    [int]$newEggs
  )

  #loop through creating each all day egg count with emoji
  for ($i = 0; $i -lt $newEggs; $i++) {
    $currEgg = $eggCount + $i + 1
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
  
}

function Get-StatData {
  param (
    [datetime]$dateTime
  )

  $eggsPerDay = [int[]]::new(7)
  $currStart = ($dateTime.ToString("yyyy-MM-ddT00:00:00Z"))
  $currEnd = ((Get-Date).AddDays(1)).ToString("yyyy-MM-ddT00:00:00Z")

  #Get egg count from start
  $statsEventsBody = @{"timeMin" = "$currStart"
    "timeMax"                    = "$currEnd"
    "maxResults"                 = 2500
    "singleEvents"               = "$true"
    "orderBy"                    = "startTime"
  }
  $statsCalEvents = Invoke-RestMethod -Headers @{"Authorization" = "Bearer $accessToken" } `
    -Uri $requestUri `
    -Method Get `
    -Body $statsEventsBody `
    -ContentType 'application/json'

  foreach ($item in $($statsCalEvents.items)) {
    $currDay = ([datetime]$item.start.date)
    
    if (($item.summary).contains("`u{1F95A}")) {

      switch ($currDay.DayOfWeek) {
        "Monday" { $eggsPerDay[0]++ }
        "Tuesday" { $eggsPerDay[1]++ }
        "Wednesday" { $eggsPerDay[2]++ }
        "Thursday" { $eggsPerDay[3]++ }
        "Friday" { $eggsPerDay[4]++ }
        "Saturday" { $eggsPerDay[5]++ }
        "Sunday" { $eggsPerDay[6]++ }
        Default { Throw "something happened!!!" }
      }
      
    }
  }

  return $eggsPerDay
}

function Show-StatData {
  param (
    [datetime]$dateTime
  )

  #collect data
  $start = Get-Date
  $statsArr = Get-StatData -dateTime $dateTime
  $end = Get-Date
  Write-host "$(New-TimeSpan -Start $start -End $end)"

  #Gui Creation and user input for egg count
  $statsForm = New-Object System.Windows.Forms.Form
  $statsForm.Text = 'Egg Counter Stats'
  $statsForm.Size = New-Object System.Drawing.Size(300, 300)
  $statsForm.StartPosition = 'CenterParent'

  $backButton = New-Object System.Windows.Forms.Button
  $backButton.Location = New-Object System.Drawing.Point(100, 175)
  $backButton.Size = New-Object System.Drawing.Size(75, 23)
  $backButton.Text = 'EXIT'
  $backButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $statsForm.AcceptButton = $backButton
  $statsForm.Controls.Add($backButton)

  $label = New-Object System.Windows.Forms.Label
  $label.Location = New-Object System.Drawing.Point(10, 0)
  $label.Size = New-Object System.Drawing.Size(280, 160)
  $label.Text = "DayOfWeek Total Avgerage

Monday:       $($statsArr[0])   $([math]::round($($statsArr[0][0])/$weeksSince,2))
Tuesday:      $($statsArr[1])   $([math]::round($($statsArr[1][0])/$weeksSince,2))
Wednesday: $($statsArr[2])   $([math]::round($($statsArr[2][0])/$weeksSince,2))
Thursday:   $($statsArr[3])   $([math]::round($($statsArr[3][0])/$weeksSince,2))
Friday:        $($statsArr[4])   $([math]::round($($statsArr[4][0])/$weeksSince,2))
Saturday:   $($statsArr[5])   $([math]::round($($statsArr[5][0])/$weeksSince,2))
Sunday:      $($statsArr[6])   $([math]::round($($statsArr[6][0])/$weeksSince,2))
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
#get egg count from yesterday
$eggCount = Get-YesterdayEggs -Start $yesterday -End $endOfToday

#get/create stats to be displyed
$dailyAvg = $eggCount / $daysSince
$weeklyAvg = $eggCount / $weeksSince
$monthlyAvg = $eggCount / $monthsSince

#Gui Creation and user input for egg count
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Egg Counter'
$form.Size = New-Object System.Drawing.Size(300, 300)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75, 160)
$okButton.Size = New-Object System.Drawing.Size(75, 23)
$okButton.Text = 'Add'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$statButton = New-Object System.Windows.Forms.Button
$statButton.Location = New-Object System.Drawing.Point(150, 160)
$statButton.Size = New-Object System.Drawing.Size(75, 23)
$statButton.Text = 'More Stats'
$form.Controls.Add($statButton)
$statButton.Add_Click({ Show-StatData -dateTime $startDateTime })

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
  Add-NewEggs -newEggs $x
}