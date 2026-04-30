# interface pour récuperer l'ip du pc et de modifier la configuration

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-SelectedIpv4Configuration {
    param(
        [string]$InterfaceAlias
    )

    $address = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '169.254.*' } |
        Sort-Object SkipAsSource |
        Select-Object -First 1

    $gatewayInfo = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias -ErrorAction SilentlyContinue
    $gateway = $gatewayInfo.IPv4DefaultGateway.NextHop
    $dnsInfo = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsServers = @($dnsInfo.ServerAddresses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ipInterface = Get-NetIPInterface -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        IPAddress    = $address.IPAddress
        PrefixLength = $address.PrefixLength
        Gateway      = $gateway
        DnsServers   = $dnsServers
        DhcpEnabled  = ($ipInterface.Dhcp -eq 'Enabled')
    }
}

function Set-StaticControlsState {
    param(
        [bool]$Enabled
    )

    $textBoxIP.Enabled = $Enabled
    $textBoxMask.Enabled = $Enabled
    $textBoxGateway.Enabled = $Enabled
}

function Refresh-NetworkDisplay {
    $selectedInterface = [string]$comboInterface.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedInterface)) {
        $labelCurrentIP.Text = 'Aucune carte reseau selectionnee.'
        return
    }

    try {
        $config = Get-SelectedIpv4Configuration -InterfaceAlias $selectedInterface
        $dnsText = if ($config.DnsServers.Count -gt 0) { $config.DnsServers -join ', ' } else { 'Automatique' }

        if ($config.DhcpEnabled) {
            $radioDynamic.Checked = $true
        } else {
            $radioStatic.Checked = $true
        }

        Set-StaticControlsState -Enabled (-not $config.DhcpEnabled)
        $textBoxDnsPrimary.Text = if ($config.DnsServers.Count -ge 1) { $config.DnsServers[0] } else { '' }
        $textBoxDnsSecondary.Text = if ($config.DnsServers.Count -ge 2) { $config.DnsServers[1] } else { '' }

        if ($null -eq $config.IPAddress) {
            $modeText = if ($config.DhcpEnabled) { 'DHCP' } else { 'Statique' }
            $labelCurrentIP.Text = "Mode : $modeText`r`nAucune adresse IPv4 configuree.`r`nDNS : $dnsText"
            $textBoxIP.Text = ''
            $textBoxMask.Text = ''
            $textBoxGateway.Text = if ($config.Gateway) { $config.Gateway } else { '' }
            return
        }

        $gatewayText = if ([string]::IsNullOrWhiteSpace($config.Gateway)) { 'Aucune' } else { $config.Gateway }
        $modeText = if ($config.DhcpEnabled) { 'DHCP' } else { 'Statique' }
        $labelCurrentIP.Text = "Mode : $modeText`r`nIP : $($config.IPAddress)`r`nPrefixe : $($config.PrefixLength)`r`nPasserelle : $gatewayText`r`nDNS : $dnsText"
        $textBoxIP.Text = $config.IPAddress
        $textBoxMask.Text = [string]$config.PrefixLength
        $textBoxGateway.Text = if ($gatewayText -eq 'Aucune') { '' } else { $gatewayText }
    } catch {
        $labelCurrentIP.Text = "Erreur de lecture : $($_.Exception.Message)"
    }
}

$networkInterfaces = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -ne 'Disabled' } |
    Sort-Object Name |
    Select-Object -ExpandProperty Name

$Form = New-Object System.Windows.Forms.Form

# Astuce Pro : On demande à l'interface de récupérer l'icône qui est intégrée dans l'exécutable en cours
$CheminExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

$Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($CheminExe)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gestionnaire de Configuration Reseau'
$form.Size = New-Object System.Drawing.Size(650, 680)
$form.MinimumSize = New-Object System.Drawing.Size(650, 680)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = 'Gestionnaire de Configuration Reseau'
$labelTitle.Location = New-Object System.Drawing.Point(20, 20)
$labelTitle.Size = New-Object System.Drawing.Size(420, 30)
$labelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = [System.Drawing.Color]::DarkBlue

$logoPath = Join-Path $PSScriptRoot 'IpConfiguratorLogo.png'
$pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
$pictureBoxLogo.Location = New-Object System.Drawing.Point(455, 5)
$pictureBoxLogo.Size = New-Object System.Drawing.Size(180, 55)
$pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
if (Test-Path $logoPath) {
    $pictureBoxLogo.Image = [System.Drawing.Image]::FromFile($logoPath)
}

$labelInterface = New-Object System.Windows.Forms.Label
$labelInterface.Text = 'Selectionnez la carte reseau :'
$labelInterface.Location = New-Object System.Drawing.Point(20, 55)
$labelInterface.Size = New-Object System.Drawing.Size(610, 20)
$labelInterface.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

$comboInterface = New-Object System.Windows.Forms.ComboBox
$comboInterface.Location = New-Object System.Drawing.Point(20, 80)
$comboInterface.Size = New-Object System.Drawing.Size(610, 30)
$comboInterface.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$comboInterface.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($interface in $networkInterfaces) {
    [void]$comboInterface.Items.Add($interface)
}
if ($comboInterface.Items.Count -gt 0) {
    $comboInterface.SelectedIndex = 0
}

$labelCurrentInfo = New-Object System.Windows.Forms.Label
$labelCurrentInfo.Text = 'Configuration actuelle :'
$labelCurrentInfo.Location = New-Object System.Drawing.Point(20, 120)
$labelCurrentInfo.Size = New-Object System.Drawing.Size(610, 20)
$labelCurrentInfo.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

$labelCurrentIP = New-Object System.Windows.Forms.Label
$labelCurrentIP.Text = 'En attente...'
$labelCurrentIP.Location = New-Object System.Drawing.Point(20, 145)
$labelCurrentIP.Size = New-Object System.Drawing.Size(580, 140)
$labelCurrentIP.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$labelCurrentIP.ForeColor = [System.Drawing.Color]::DarkGreen
$labelCurrentIP.BackColor = [System.Drawing.Color]::AliceBlue
$labelCurrentIP.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$labelCurrentIP.Padding = New-Object System.Windows.Forms.Padding(10)

$buttonRefresh = New-Object System.Windows.Forms.Button
$buttonRefresh.Text = "↻"
$buttonRefresh.Location = New-Object System.Drawing.Point(605, 145)
$buttonRefresh.Size = New-Object System.Drawing.Size(25, 140)
$buttonRefresh.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 10)
$buttonRefresh.BackColor = [System.Drawing.Color]::LightBlue
$buttonRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$buttonRefresh.Add_Click({
    Refresh-NetworkDisplay
})

$comboInterface.Add_SelectedIndexChanged({
    Refresh-NetworkDisplay
})

$labelNewConfig = New-Object System.Windows.Forms.Label
$labelNewConfig.Text = 'Nouvelle configuration :'
$labelNewConfig.Location = New-Object System.Drawing.Point(20, 305)
$labelNewConfig.Size = New-Object System.Drawing.Size(610, 20)
$labelNewConfig.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

$radioStatic = New-Object System.Windows.Forms.RadioButton
$radioStatic.Text = 'Statique'
$radioStatic.Location = New-Object System.Drawing.Point(20, 335)
$radioStatic.Size = New-Object System.Drawing.Size(120, 24)
$radioStatic.Checked = $true
$radioStatic.Add_CheckedChanged({
    if ($radioStatic.Checked) {
        Set-StaticControlsState -Enabled $true
    }
})

$radioDynamic = New-Object System.Windows.Forms.RadioButton
$radioDynamic.Text = 'Dynamique (DHCP)'
$radioDynamic.Location = New-Object System.Drawing.Point(160, 335)
$radioDynamic.Size = New-Object System.Drawing.Size(180, 24)
$radioDynamic.Add_CheckedChanged({
    if ($radioDynamic.Checked) {
        Set-StaticControlsState -Enabled $false
    }
})

$labelIP = New-Object System.Windows.Forms.Label
$labelIP.Text = 'Adresse IP :'
$labelIP.Location = New-Object System.Drawing.Point(20, 370)
$labelIP.Size = New-Object System.Drawing.Size(610, 20)
$labelIP.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$textBoxIP = New-Object System.Windows.Forms.TextBox
$textBoxIP.Location = New-Object System.Drawing.Point(20, 395)
$textBoxIP.Size = New-Object System.Drawing.Size(610, 30)
$textBoxIP.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$labelMask = New-Object System.Windows.Forms.Label
$labelMask.Text = 'Prefixe reseau (CIDR, ex : 24) :'
$labelMask.Location = New-Object System.Drawing.Point(20, 435)
$labelMask.Size = New-Object System.Drawing.Size(610, 20)
$labelMask.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$textBoxMask = New-Object System.Windows.Forms.TextBox
$textBoxMask.Location = New-Object System.Drawing.Point(20, 460)
$textBoxMask.Size = New-Object System.Drawing.Size(610, 30)
$textBoxMask.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$labelGateway = New-Object System.Windows.Forms.Label
$labelGateway.Text = 'Passerelle par defaut :'
$labelGateway.Location = New-Object System.Drawing.Point(20, 500)
$labelGateway.Size = New-Object System.Drawing.Size(610, 20)
$labelGateway.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$textBoxGateway = New-Object System.Windows.Forms.TextBox
$textBoxGateway.Location = New-Object System.Drawing.Point(20, 525)
$textBoxGateway.Size = New-Object System.Drawing.Size(610, 30)
$textBoxGateway.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$labelDnsPrimary = New-Object System.Windows.Forms.Label
$labelDnsPrimary.Text = 'DNS primaire :'
$labelDnsPrimary.Location = New-Object System.Drawing.Point(20, 565)
$labelDnsPrimary.Size = New-Object System.Drawing.Size(610, 20)
$labelDnsPrimary.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$textBoxDnsPrimary = New-Object System.Windows.Forms.TextBox
$textBoxDnsPrimary.Location = New-Object System.Drawing.Point(20, 590)
$textBoxDnsPrimary.Size = New-Object System.Drawing.Size(610, 30)
$textBoxDnsPrimary.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$labelDnsSecondary = New-Object System.Windows.Forms.Label
$labelDnsSecondary.Text = 'DNS secondaire :'
$labelDnsSecondary.Location = New-Object System.Drawing.Point(20, 630)
$labelDnsSecondary.Size = New-Object System.Drawing.Size(610, 20)
$labelDnsSecondary.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$textBoxDnsSecondary = New-Object System.Windows.Forms.TextBox
$textBoxDnsSecondary.Location = New-Object System.Drawing.Point(20, 655)
$textBoxDnsSecondary.Size = New-Object System.Drawing.Size(610, 30)
$textBoxDnsSecondary.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$buttonApply = New-Object System.Windows.Forms.Button
$buttonApply.Text = 'Appliquer'
$buttonApply.Location = New-Object System.Drawing.Point(20, 710)
$buttonApply.Size = New-Object System.Drawing.Size(140, 40)
$buttonApply.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$buttonApply.BackColor = [System.Drawing.Color]::LightGreen
$buttonApply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$buttonApply.Add_Click({
    $selectedInterface = [string]$comboInterface.SelectedItem
    $ip = $textBoxIP.Text.Trim()
    $prefixText = $textBoxMask.Text.Trim()
    $gateway = $textBoxGateway.Text.Trim()
    $dnsServers = @($textBoxDnsPrimary.Text.Trim(), $textBoxDnsSecondary.Text.Trim()) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ([string]::IsNullOrWhiteSpace($selectedInterface)) {
        [System.Windows.Forms.MessageBox]::Show('Veuillez selectionner une carte reseau.', 'Erreur', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $adapter = Get-NetAdapter -InterfaceAlias $selectedInterface -ErrorAction Stop
        $interfaceIndex = $adapter.ifIndex

        if ($radioDynamic.Checked) {
            Set-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop | Out-Null
            Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.PrefixOrigin -eq 'Manual' -and $_.IPAddress -notlike '169.254.*' } |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
            Get-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        } else {
            if ([string]::IsNullOrWhiteSpace($ip) -or [string]::IsNullOrWhiteSpace($prefixText)) {
                [System.Windows.Forms.MessageBox]::Show('Veuillez renseigner l''adresse IP et le prefixe reseau.', 'Erreur', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $prefixLength = 0
            if (-not [int]::TryParse($prefixText, [ref]$prefixLength) -or $prefixLength -lt 0 -or $prefixLength -gt 32) {
                [System.Windows.Forms.MessageBox]::Show('Le prefixe doit etre un entier entre 0 et 32.', 'Erreur', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            Set-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Dhcp Disabled -ErrorAction Stop | Out-Null
            Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike '169.254.*' } |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

            if (-not [string]::IsNullOrWhiteSpace($gateway)) {
                Get-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
                New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $ip -PrefixLength $prefixLength -DefaultGateway $gateway -AddressFamily IPv4 -ErrorAction Stop | Out-Null
            } else {
                New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $ip -PrefixLength $prefixLength -AddressFamily IPv4 -ErrorAction Stop | Out-Null
            }
        }

        if ($dnsServers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $dnsServers -ErrorAction Stop | Out-Null
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ResetServerAddresses -ErrorAction Stop | Out-Null
        }

        [System.Windows.Forms.MessageBox]::Show("Configuration appliquee avec succes sur $selectedInterface.", 'Succes', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Refresh-NetworkDisplay
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur lors de l'application : $($_.Exception.Message)", 'Erreur', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = 'Effacer'
$buttonCancel.Location = New-Object System.Drawing.Point(170, 710)
$buttonCancel.Size = New-Object System.Drawing.Size(140, 40)
$buttonCancel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$buttonCancel.BackColor = [System.Drawing.Color]::LightCoral
$buttonCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$buttonCancel.Add_Click({
    $textBoxIP.Text = ''
    $textBoxMask.Text = ''
    $textBoxGateway.Text = ''
    $textBoxDnsPrimary.Text = ''
    $textBoxDnsSecondary.Text = ''
})

$buttonClose = New-Object System.Windows.Forms.Button
$buttonClose.Text = 'Fermer'
$buttonClose.Location = New-Object System.Drawing.Point(320, 710)
$buttonClose.Size = New-Object System.Drawing.Size(310, 40)
$buttonClose.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$buttonClose.BackColor = [System.Drawing.Color]::LightGray
$buttonClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$buttonClose.Add_Click({
    $form.Close()
})

$labelInfo = New-Object System.Windows.Forms.Label
$labelInfo.Text = 'Vous devez executer ce script en tant qu''administrateur pour modifier la configuration reseau.'
$labelInfo.Location = New-Object System.Drawing.Point(20, 770)
$labelInfo.Size = New-Object System.Drawing.Size(610, 60)
$labelInfo.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$labelInfo.ForeColor = [System.Drawing.Color]::DarkRed

$form.Size = New-Object System.Drawing.Size(650, 900)
$form.MinimumSize = New-Object System.Drawing.Size(650, 900)

$form.Controls.Add($labelTitle)
$form.Controls.Add($pictureBoxLogo)
$form.Controls.Add($labelInterface)
$form.Controls.Add($comboInterface)
$form.Controls.Add($labelCurrentInfo)
$form.Controls.Add($labelCurrentIP)
$form.Controls.Add($buttonRefresh)
$form.Controls.Add($labelNewConfig)
$form.Controls.Add($radioStatic)
$form.Controls.Add($radioDynamic)
$form.Controls.Add($labelIP)
$form.Controls.Add($textBoxIP)
$form.Controls.Add($labelMask)
$form.Controls.Add($textBoxMask)
$form.Controls.Add($labelGateway)
$form.Controls.Add($textBoxGateway)
$form.Controls.Add($labelDnsPrimary)
$form.Controls.Add($textBoxDnsPrimary)
$form.Controls.Add($labelDnsSecondary)
$form.Controls.Add($textBoxDnsSecondary)
$form.Controls.Add($buttonApply)
$form.Controls.Add($buttonCancel)
$form.Controls.Add($buttonClose)
$form.Controls.Add($labelInfo)

if ($comboInterface.Items.Count -gt 0) {
    Refresh-NetworkDisplay
} else {
    $labelCurrentIP.Text = 'Aucune carte reseau detectee.'
}

[void]$form.ShowDialog()
