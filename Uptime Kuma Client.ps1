# Load Windows Forms and Drawing assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Path for the settings file
$settingsFilePath = "uptimeKumaClientSettings.json"

# Function to load settings from a file
function Load-Settings {
    if (Test-Path $settingsFilePath) {
        try {
            $settings = Get-Content $settingsFilePath | ConvertFrom-Json
            $global:ipAddress = $settings.ipAddress
            $global:url = $settings.url
            $global:updateInterval = $settings.updateInterval
        } catch {
            Write-Host "Failed to load settings."
        }
    }
}

# Function to save settings to a file
function Save-Settings {
    $settings = @{
        ipAddress = $global:ipAddress
        url = $global:url
        updateInterval = $global:updateInterval
    }

    $settings | ConvertTo-Json | Set-Content $settingsFilePath
}

# Initialize default values for IP address, URL, and update interval (in seconds)
$defaultIpAddress = "192.168.1.1"
$defaultUrl = "https://uptime.kuma.push.url"
$defaultUpdateInterval = 30  # seconds

# Load the settings or set to default if the file does not exist
Load-Settings
$global:ipAddress = if ($null -ne $global:ipAddress) { $global:ipAddress } else { $defaultIpAddress }
$global:url = if ($null -ne $global:url) { $global:url } else { $defaultUrl }
$global:updateInterval = if ($null -ne $global:updateInterval) { $global:updateInterval } else { $defaultUpdateInterval }

# Variables to keep track of the first up time, consecutive failures, and last seen online time
$global:firstUpTimeToday = $null
$global:consecutiveFailures = 0
$global:today = Get-Date -Format "yyyy-MM-dd"
$global:lastOnlineTime = $null

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Uptime Kuma Client'
$form.Size = New-Object System.Drawing.Size(290, 350)

# Load a custom icon for the form
$iconPath = "uptimekuma.ico" # Replace with the path to your icon file
if (Test-Path $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
}

# Create text boxes and labels for IP address and URL
$labelIpAddress = New-Object System.Windows.Forms.Label
$labelIpAddress.Location = New-Object System.Drawing.Point(10, 10)
$labelIpAddress.Size = New-Object System.Drawing.Size(100, 20)
$labelIpAddress.Text = "IP Address:"

$textBoxIpAddress = New-Object System.Windows.Forms.TextBox
$textBoxIpAddress.Location = New-Object System.Drawing.Point(120, 10)
$textBoxIpAddress.Size = New-Object System.Drawing.Size(150, 20)
$textBoxIpAddress.Text = $global:ipAddress

$labelUrl = New-Object System.Windows.Forms.Label
$labelUrl.Location = New-Object System.Drawing.Point(10, 40)
$labelUrl.Size = New-Object System.Drawing.Size(100, 20)
$labelUrl.Text = "URL:"

$textBoxUrl = New-Object System.Windows.Forms.TextBox
$textBoxUrl.Location = New-Object System.Drawing.Point(120, 40)
$textBoxUrl.Size = New-Object System.Drawing.Size(150, 20)
$textBoxUrl.Text = $global:url

# Create text box and label for update interval (in seconds)
$labelUpdateInterval = New-Object System.Windows.Forms.Label
$labelUpdateInterval.Location = New-Object System.Drawing.Point(10, 70)
$labelUpdateInterval.Size = New-Object System.Drawing.Size(100, 20)
$labelUpdateInterval.Text = "Update in sec.:"

$textBoxUpdateInterval = New-Object System.Windows.Forms.TextBox
$textBoxUpdateInterval.Location = New-Object System.Drawing.Point(120, 70)
$textBoxUpdateInterval.Size = New-Object System.Drawing.Size(150, 20)
$textBoxUpdateInterval.Text = $global:updateInterval

# Create a multiline text box for output
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(10, 100)
$outputBox.Size = New-Object System.Drawing.Size(250, 150)
$outputBox.MultiLine = $true
$outputBox.ReadOnly = $true

# Create an update settings button
$updateButton = New-Object System.Windows.Forms.Button
$updateButton.Location = New-Object System.Drawing.Point(10, 260)
$updateButton.Size = New-Object System.Drawing.Size(100, 23)
$updateButton.Text = 'Update Settings'
$updateButton.Add_Click({
    $global:ipAddress = $textBoxIpAddress.Text
    $global:url = $textBoxUrl.Text
    $newInterval = [int]$textBoxUpdateInterval.Text
    if ($newInterval -gt 0) {
        $global:updateInterval = $newInterval
        $timer.Interval = $global:updateInterval * 1000  # Convert seconds to milliseconds
    }
    Save-Settings
    $outputBox.AppendText("Settings updated and saved!`r`n")
})

# Create an exit button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(120, 260)
$exitButton.Size = New-Object System.Drawing.Size(75, 23)
$exitButton.Text = 'Exit'
$exitButton.Add_Click({ $form.Close() })

# Add the controls to the form
$form.Controls.Add($labelIpAddress)
$form.Controls.Add($textBoxIpAddress)
$form.Controls.Add($labelUrl)
$form.Controls.Add($textBoxUrl)
$form.Controls.Add($labelUpdateInterval)
$form.Controls.Add($textBoxUpdateInterval)
$form.Controls.Add($outputBox)
$form.Controls.Add($updateButton)
$form.Controls.Add($exitButton)

# Timer setup
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $global:updateInterval * 1000  # Convert seconds to milliseconds

$timer.Add_Tick({
    # Check if it's a new day
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    if ($global:today -ne $currentDate) {
        $global:today = $currentDate
        $global:firstUpTimeToday = $null
        $global:consecutiveFailures = 0
    }

    if (Test-Connection -ComputerName $ipAddress -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        $global:consecutiveFailures = 0
        $global:lastOnlineTime = Get-Date
        if ($global:firstUpTimeToday -eq $null) {
            $global:firstUpTimeToday = Get-Date -Format "HH:mm:ss"
        }
        $outputBox.AppendText("$ipAddress is online. First Up Today: $($global:firstUpTimeToday)`r`n")

        # Execute the URL with curl when the IP is online
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
            # Optional: Handle the response if needed
        }
        catch {
            $outputBox.AppendText("Failed to execute the URL: $_`r`n")
        }
    } else {
        $global:consecutiveFailures += 1
        if ($global:lastOnlineTime -ne $null) {
            $timeLastSeen = New-TimeSpan -Start $global:lastOnlineTime -End (Get-Date)
            $outputBox.AppendText("$ipAddress is OFFLINE since $($timeLastSeen.ToString('dd\.hh\:mm\:ss'))!`r`n")
        } else {
            $outputBox.AppendText("$ipAddress is OFFLINE!`r`n")
        }
    }
})

# Append initial message to output box
$outputBox.AppendText("Monitoring started.`r`n")

# Start the timer
$timer.Start()

# Show the form
$form.ShowDialog()

# Stop the timer when the form closes
$timer.Stop()
