Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- 1. CONFIGURACION ---
$scriptPath = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
if ($scriptPath -like "*System32*") { $scriptPath = [Environment]::GetFolderPath("Desktop") }
$configFile = "config_ruta.cfg"
$steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
$steamCmdDir = Join-Path $scriptPath "SteamCMD"
$steamCmdExe = Join-Path $steamCmdDir "steamcmd.exe"

# --- 2. ESTILOS ---
$C_Bg       = [System.Drawing.ColorTranslator]::FromHtml("#1E1E1E")
$C_Panel    = [System.Drawing.ColorTranslator]::FromHtml("#252526")
$C_Input    = [System.Drawing.ColorTranslator]::FromHtml("#333337")
$C_Text     = [System.Drawing.ColorTranslator]::FromHtml("#F1F1F1")
$C_Gold     = [System.Drawing.ColorTranslator]::FromHtml("#FFD700")
$C_Blue     = [System.Drawing.ColorTranslator]::FromHtml("#007ACC")
$C_Green    = [System.Drawing.ColorTranslator]::FromHtml("#4CAF50")
$C_Red      = [System.Drawing.ColorTranslator]::FromHtml("#E51400")
$C_GrayBtn  = [System.Drawing.ColorTranslator]::FromHtml("#3E3E42")

$F_Title    = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$F_Header   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$F_Normal   = New-Object System.Drawing.Font("Segoe UI", 8) 
$F_Small    = New-Object System.Drawing.Font("Segoe UI", 7)
$F_Console  = New-Object System.Drawing.Font("Consolas", 8)

# --- 3. AYUDA DETALLADA (RESTAURADA) ---
$HelpTextContent = @"
GUIA COMPLETA DE USO - CONAN MOD MANAGER
========================================

[PASO 1: PREPARACION INICIAL]
1. Coloca este programa (el .exe) en una carpeta propia.
   (Ejemplo: Escritorio\GestorConan).
2. Al abrirlo, intentara detectar tu juego automaticamente.
   Si falla, usa el boton "..." para buscar la carpeta "Content" manualmente.
   (Ruta tipica: C:\XboxGames\Conan Exiles\Content)

[PASO 2: DESCARGAR MODS (STEAM)]
1. Busca los mods en la web de Steam Workshop.
2. Copia los LINKS (URL) o los numeros de ID.
3. En el programa, pulsa "Importar" y pega la lista ahi.
4. Pulsa "PROCESAR" y luego "DESCARGAR".
   *NOTA: Se abrira una ventana negra. NO la cierres, espera a que termine.*

[PASO 3: ESTADO Y ORDEN]
1. En la lista veras los mods. Las etiquetas [INSTALADO: C/S] te dicen
   si ya lo tienes en el Cliente o Servidor.
2. Usa el boton 'Ref' para actualizar estos estados.
3. Usa los botones [ ^ ] y [ v ] a la derecha para mover la prioridad.
   (Los de arriba cargan primero).

[PASO 4: INSTALACION FINAL]
1. Marca las casillas de los mods que quieres usar/actualizar.
2. Elige destino: "Cliente" (Tu PC) y/o "Servidor" (Si hosteas).
3. FIX GAME PASS: Deja marcada la opcion "Fix Firmas".
4. Dale al boton dorado "INSTALAR EN ORDEN".

[HERRAMIENTAS EXTRA]
- BACKUP: Crea una copia de seguridad en la carpeta Backups.
- VERIFICAR: Lee el archivo 'modlist.txt' real y muestra que mods estan activos.
- LIMPIAR: Borra todos los mods del juego (util si crashea).

[SOLUCION DE PROBLEMAS]
- Error de descarga? Revisa tu internet. SteamCMD a veces falla, reintenta.
- El juego no abre? Usa "LIMPIAR", luego "INSTALAR" con "Fix Firmas".
"@

# --- 4. LOGICA ---
function Log-Write($text) {
    $time = Get-Date -Format "HH:mm"
    $txtLog.AppendText(" [$time] $text`r`n")
    $txtLog.ScrollToCaret()
}

function Save-Config { $txtPath.Text | Set-Content (Join-Path $scriptPath $configFile) }

function Get-Paths {
    return @{
        Base = $txtPath.Text
        Client = Join-Path $txtPath.Text "WindowsNoEditor\ConanSandbox\Mods"
        Server = Join-Path $txtPath.Text "WindowsServer\ConanSandbox\Mods"
    }
}

# --- SMART STATUS REFRESH ---
function Refresh-ModList {
    $clbMods.Items.Clear()
    $pakFiles = Get-ChildItem "$scriptPath\*.pak"
    $paths = Get-Paths
    $checkInstall = -not [string]::IsNullOrWhiteSpace($txtPath.Text)

    if ($pakFiles) {
        foreach ($pak in $pakFiles) {
            $statusTag = ""
            if ($checkInstall) {
                $inC = Test-Path "$($paths.Client)\$($pak.Name)"
                $inS = Test-Path "$($paths.Server)\$($pak.Name)"
                if ($inC -and $inS) { $statusTag = "   [INSTALADO: C+S]" }
                elseif ($inC) { $statusTag = "   [INSTALADO: C]" }
                elseif ($inS) { $statusTag = "   [INSTALADO: S]" }
            }
            $clbMods.Items.Add("$($pak.Name)$statusTag", $true)
        }
        $lblStatus.Text = "$($pakFiles.Count) mods encontrados."
        $lblStatus.ForeColor = $C_Green
    } else {
        $lblStatus.Text = "Carpeta vacia."
        $lblStatus.ForeColor = [System.Drawing.Color]::Orange
    }
}

function Find-GamePath {
    Log-Write "Escaneando discos..."
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($d in $drives) {
        foreach ($folder in @("XboxGames", "Xbox")) {
            $p = "$($d.Root)$folder\Conan Exiles\Content"
            if (Test-Path "$p\WindowsNoEditor") { return $p }
        }
    }
    return $null
}

function Load-Config {
    $cfg = Join-Path $scriptPath $configFile
    if (Test-Path $cfg) { $txtPath.Text = Get-Content $cfg; Log-Write "Configuracion cargada." }
    else { $auto = Find-GamePath; if ($auto) { $txtPath.Text = $auto; Save-Config } }
    Refresh-ModList
}

# --- 5. STEAMCMD ---
function Init-SteamCMD {
    if (-not (Test-Path $steamCmdExe)) {
        Log-Write "Instalando SteamCMD..."
        if (-not (Test-Path $steamCmdDir)) { New-Item -ItemType Directory -Path $steamCmdDir | Out-Null }
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $steamCmdUrl -OutFile "$steamCmdDir\steamcmd.zip"
            [System.IO.Compression.ZipFile]::ExtractToDirectory("$steamCmdDir\steamcmd.zip", $steamCmdDir)
            Remove-Item "$steamCmdDir\steamcmd.zip"
            Start-Process -FilePath $steamCmdExe -ArgumentList "+quit" -PassThru -Wait | Out-Null
        } catch { Log-Write "Error critico instalando SteamCMD."; return $false }
    }
    return $true
}

function Extract-ID ($raw) {
    if ($raw -match "id=(\d+)") { return $Matches[1] }
    if ($raw -match "^\d+$") { return $raw.Trim() }
    return $null
}

function Download-Mods {
    if ([string]::IsNullOrWhiteSpace($txtModIds.Text)) { return }
    if (-not (Init-SteamCMD)) { return }

    $rawList = $txtModIds.Text -split ","
    $idList = @()
    foreach ($r in $rawList) { $v = Extract-ID $r; if($v){$idList+=$v} }
    
    if ($idList.Count -eq 0) { Log-Write "No hay IDs validos."; return }

    Log-Write "Descargando $($idList.Count) mods..."
    $sScript = "$steamCmdDir\dl.txt"
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("login anonymous") | Out-Null
    foreach ($id in $idList) { $sb.AppendLine("workshop_download_item 440900 $id") | Out-Null }
    $sb.AppendLine("quit") | Out-Null
    [System.IO.File]::WriteAllText($sScript, $sb.ToString(), [System.Text.Encoding]::ASCII)

    $bat = "$steamCmdDir\run.bat"
    [System.IO.File]::WriteAllText($bat, "@echo off`ncd /d `"%~dp0`"`nsteamcmd +runscript dl.txt", [System.Text.Encoding]::ASCII)
    
    Start-Process -FilePath $bat -Wait
    
    $wsDir = "$steamCmdDir\steamapps\workshop\content\440900"
    foreach ($id in $idList) {
        if (Test-Path "$wsDir\$id") {
            Get-ChildItem "$wsDir\$id" -Filter "*.pak" -Recurse | Copy-Item -Destination $scriptPath -Force
            Log-Write "Mod $id OK."
        } else { Log-Write "Fallo descarga ID $id" }
    }
    Refresh-ModList
    [System.Windows.Forms.MessageBox]::Show("Descarga finalizada.", "Listo", "OK", "Information")
}

# --- 6. INTERFAZ GRAFICA ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Conan Mod Manager v50 (Gold Edition)"
$form.Size = New-Object System.Drawing.Size(660, 700) 
$form.StartPosition = "CenterScreen"
$form.BackColor = $C_Bg
$form.ForeColor = $C_Text
$form.Font = $F_Normal
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.AutoScroll = $true 

# HEADER
$pnlHeader = New-Object System.Windows.Forms.Panel; $pnlHeader.Dock="Top"; $pnlHeader.Height=35; $pnlHeader.BackColor=$C_Panel; $form.Controls.Add($pnlHeader)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="CONAN EXILES MOD MANAGER"; $lblTitle.AutoSize=$false; $lblTitle.Dock="Fill"; $lblTitle.TextAlign="MiddleCenter"; $lblTitle.Font=$F_Title; $lblTitle.ForeColor=$C_Gold; $pnlHeader.Controls.Add($lblTitle)

# DESCARGA
$grpDown = New-Object System.Windows.Forms.GroupBox; $grpDown.Text="1. DESCARGA (STEAM)"; $grpDown.Location=New-Object System.Drawing.Point(15,45); $grpDown.Size=New-Object System.Drawing.Size(610,80); $grpDown.ForeColor=$C_Blue; $grpDown.Font=$F_Header; $form.Controls.Add($grpDown)
$txtModIds = New-Object System.Windows.Forms.TextBox; $txtModIds.Location=New-Object System.Drawing.Point(15,30); $txtModIds.Size=New-Object System.Drawing.Size(325,23); $txtModIds.BackColor=$C_Input; $txtModIds.ForeColor=$C_Text; $txtModIds.BorderStyle="FixedSingle"; $txtModIds.Font=$F_Normal; $grpDown.Controls.Add($txtModIds)

$btnImport = New-Object System.Windows.Forms.Button; $btnImport.Text="Importar"; $btnImport.Location=New-Object System.Drawing.Point(350,29); $btnImport.Size=New-Object System.Drawing.Size(65,25); $btnImport.FlatStyle="Flat"; $btnImport.FlatAppearance.BorderSize=0; $btnImport.BackColor=$C_GrayBtn; $btnImport.ForeColor="White"; $btnImport.Font=$F_Small; $btnImport.Cursor="Hand"; $grpDown.Controls.Add($btnImport)
$btnDL = New-Object System.Windows.Forms.Button; $btnDL.Text="DESCARGAR"; $btnDL.Location=New-Object System.Drawing.Point(425,29); $btnDL.Size=New-Object System.Drawing.Size(100,25); $btnDL.FlatStyle="Flat"; $btnDL.FlatAppearance.BorderSize=0; $btnDL.BackColor=$C_Blue; $btnDL.ForeColor="White"; $btnDL.Font=$F_Header; $btnDL.Cursor="Hand"; $grpDown.Controls.Add($btnDL)
$btnFolder = New-Object System.Windows.Forms.Button; $btnFolder.Text="ABRIR"; $btnFolder.Location=New-Object System.Drawing.Point(535,29); $btnFolder.Size=New-Object System.Drawing.Size(60,25); $btnFolder.FlatStyle="Flat"; $btnFolder.FlatAppearance.BorderSize=0; $btnFolder.BackColor=$C_GrayBtn; $btnFolder.ForeColor="White"; $btnFolder.Cursor="Hand"; $btnFolder.Font=$F_Small; $grpDown.Controls.Add($btnFolder)

# RUTA
$grpPath = New-Object System.Windows.Forms.GroupBox; $grpPath.Text="2. RUTA DEL JUEGO"; $grpPath.Location=New-Object System.Drawing.Point(15,130); $grpPath.Size=New-Object System.Drawing.Size(610,60); $grpPath.ForeColor="#AAAAAA"; $grpPath.Font=$F_Small; $form.Controls.Add($grpPath)
$txtPath = New-Object System.Windows.Forms.TextBox; $txtPath.Location=New-Object System.Drawing.Point(15,25); $txtPath.Size=New-Object System.Drawing.Size(460,23); $txtPath.BackColor=$C_Input; $txtPath.ForeColor=$C_Text; $txtPath.BorderStyle="FixedSingle"; $txtPath.Font=$F_Normal; $grpPath.Controls.Add($txtPath)
$btnAuto = New-Object System.Windows.Forms.Button; $btnAuto.Text="AUTO"; $btnAuto.Location=New-Object System.Drawing.Point(485,24); $btnAuto.Size=New-Object System.Drawing.Size(60,25); $btnAuto.FlatStyle="Flat"; $btnAuto.FlatAppearance.BorderSize=0; $btnAuto.BackColor=$C_Blue; $btnAuto.ForeColor="White"; $btnAuto.Font=$F_Small; $btnAuto.Cursor="Hand"; $grpPath.Controls.Add($btnAuto)
$btnBrw = New-Object System.Windows.Forms.Button; $btnBrw.Text="..."; $btnBrw.Location=New-Object System.Drawing.Point(555,24); $btnBrw.Size=New-Object System.Drawing.Size(40,25); $btnBrw.FlatStyle="Flat"; $btnBrw.FlatAppearance.BorderSize=0; $btnBrw.BackColor=$C_GrayBtn; $btnBrw.ForeColor="White"; $grpPath.Controls.Add($btnBrw)

# GESTION
$grpMain = New-Object System.Windows.Forms.GroupBox; $grpMain.Text="3. ORDENAR E INSTALAR"; $grpMain.Location=New-Object System.Drawing.Point(15,195); $grpMain.Size=New-Object System.Drawing.Size(610,280); $grpMain.ForeColor=$C_Gold; $grpMain.Font=$F_Header; $form.Controls.Add($grpMain)
$lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Text="..."; $lblStatus.Location=New-Object System.Drawing.Point(15,25); $lblStatus.Size=New-Object System.Drawing.Size(250,20); $lblStatus.Font=$F_Normal; $grpMain.Controls.Add($lblStatus)

$btnAll = New-Object System.Windows.Forms.Button; $btnAll.Text="Todo"; $btnAll.Location=New-Object System.Drawing.Point(320,20); $btnAll.Size=New-Object System.Drawing.Size(60,25); $btnAll.FlatStyle="Flat"; $btnAll.BackColor=$C_GrayBtn; $btnAll.ForeColor="White"; $btnAll.Font=$F_Small; $grpMain.Controls.Add($btnAll)
$btnNone = New-Object System.Windows.Forms.Button; $btnNone.Text="Nada"; $btnNone.Location=New-Object System.Drawing.Point(390,20); $btnNone.Size=New-Object System.Drawing.Size(60,25); $btnNone.FlatStyle="Flat"; $btnNone.BackColor=$C_GrayBtn; $btnNone.ForeColor="White"; $btnNone.Font=$F_Small; $grpMain.Controls.Add($btnNone)
$btnRef = New-Object System.Windows.Forms.Button; $btnRef.Text="Ref"; $btnRef.Location=New-Object System.Drawing.Point(460,20); $btnRef.Size=New-Object System.Drawing.Size(50,25); $btnRef.FlatStyle="Flat"; $btnRef.BackColor=$C_Green; $btnRef.ForeColor="White"; $btnRef.Font=$F_Small; $grpMain.Controls.Add($btnRef)

$clbMods = New-Object System.Windows.Forms.CheckedListBox; $clbMods.Location=New-Object System.Drawing.Point(15,50); $clbMods.Size=New-Object System.Drawing.Size(530,130); $clbMods.BackColor=$C_Input; $clbMods.ForeColor="White"; $clbMods.BorderStyle="FixedSingle"; $clbMods.Font=$F_Normal; $clbMods.CheckOnClick=$true; $grpMain.Controls.Add($clbMods)

$btnUp = New-Object System.Windows.Forms.Button; $btnUp.Text="^"; $btnUp.Location=New-Object System.Drawing.Point(555,50); $btnUp.Size=New-Object System.Drawing.Size(45,60); $btnUp.FlatStyle="Flat"; $btnUp.BackColor="#333333"; $btnUp.ForeColor=$C_Gold; $btnUp.Font=$F_Small; $grpMain.Controls.Add($btnUp)
$btnDown = New-Object System.Windows.Forms.Button; $btnDown.Text="v"; $btnDown.Location=New-Object System.Drawing.Point(555,120); $btnDown.Size=New-Object System.Drawing.Size(45,60); $btnDown.FlatStyle="Flat"; $btnDown.BackColor="#333333"; $btnDown.ForeColor=$C_Gold; $btnDown.Font=$F_Small; $grpMain.Controls.Add($btnDown)

$chkClient = New-Object System.Windows.Forms.CheckBox; $chkClient.Text="Cliente"; $chkClient.Location=New-Object System.Drawing.Point(15,190); $chkClient.AutoSize=$true; $chkClient.Checked=$true; $chkClient.Font=$F_Normal; $chkClient.ForeColor="White"; $grpMain.Controls.Add($chkClient)
$chkServer = New-Object System.Windows.Forms.CheckBox; $chkServer.Text="Servidor"; $chkServer.Location=New-Object System.Drawing.Point(130,190); $chkServer.AutoSize=$true; $chkServer.Checked=$true; $chkServer.Font=$F_Normal; $chkServer.ForeColor="White"; $grpMain.Controls.Add($chkServer)
$chkSig = New-Object System.Windows.Forms.CheckBox; $chkSig.Text="Fix Firmas (.sig)"; $chkSig.Location=New-Object System.Drawing.Point(260,190); $chkSig.AutoSize=$true; $chkSig.Checked=$true; $chkSig.Font=$F_Normal; $chkSig.ForeColor=$C_Blue; $grpMain.Controls.Add($chkSig)

$btnInst = New-Object System.Windows.Forms.Button; $btnInst.Text="INSTALAR EN ORDEN"; $btnInst.Location=New-Object System.Drawing.Point(380,185); $btnInst.Size=New-Object System.Drawing.Size(220,45); $btnInst.FlatStyle="Flat"; $btnInst.FlatAppearance.BorderSize=0; $btnInst.BackColor=$C_Gold; $btnInst.ForeColor="Black"; $btnInst.Font=$F_Header; $btnInst.Cursor="Hand"; $grpMain.Controls.Add($btnInst)
$progBar = New-Object System.Windows.Forms.ProgressBar; $progBar.Location=New-Object System.Drawing.Point(15,240); $progBar.Size=New-Object System.Drawing.Size(585,10); $grpMain.Controls.Add($progBar)

# HERRAMIENTAS GRID
$pnlTools = New-Object System.Windows.Forms.Panel; $pnlTools.Location=New-Object System.Drawing.Point(15,480); $pnlTools.Size=New-Object System.Drawing.Size(610,45); $form.Controls.Add($pnlTools)
function Add-ToolBtn ($txt, $col, $x, $act) {
    $b = New-Object System.Windows.Forms.Button; $b.Text=$txt; $b.Location=New-Object System.Drawing.Point($x,0); $b.Size=New-Object System.Drawing.Size(95,35); $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0; $b.BackColor=$col; $b.ForeColor="White"; $b.Font=$F_Small; $b.Cursor="Hand"; $b.Add_Click($act); $pnlTools.Controls.Add($b)
}
Add-ToolBtn "AYUDA" $C_Blue 0 { [System.Windows.Forms.MessageBox]::Show($HelpTextContent, "Manual", "OK", "Information") }
Add-ToolBtn "BACKUP" $C_Green 103 { $p=Get-Paths; $t=Join-Path "$scriptPath\Backups" (Get-Date -Format "yyyyMMdd-HHmm"); if(Test-Path $p.Client){ New-Item -ItemType Directory -Path $t -Force|Out-Null; Copy-Item "$($p.Client)\*" $t -Recurse; Log-Write "Backup OK" } }
Add-ToolBtn "VERIFICAR" $C_GrayBtn 206 { 
    $p=Get-Paths
    function Check-List($path, $lbl) {
        if(Test-Path "$path\modlist.txt"){ 
            Log-Write "$($lbl): OK. Mods activos:" 
            Get-Content "$path\modlist.txt" | ForEach { Log-Write " > $_" }
        } else { Log-Write "$($lbl): Sin modlist" }
    }
    Check-List $p.Client "CLIENTE"
    Check-List $p.Server "SERVIDOR"
}
Add-ToolBtn "LIMPIAR" $C_Red 309 { if([System.Windows.Forms.MessageBox]::Show("Borrar todo?","!","YesNo","Warning")-eq"Yes"){ $p=Get-Paths; if($chkClient.Checked){Remove-Item "$($p.Client)\*.*" -Recurse -Force -ErrorAction SilentlyContinue; Log-Write "Cliente Limpio"}; if($chkServer.Checked){Remove-Item "$($p.Server)\*.*" -Recurse -Force -ErrorAction SilentlyContinue; Log-Write "Server Limpio"} } }
Add-ToolBtn "Dir. Cliente" $C_GrayBtn 412 { Invoke-Item (Get-Paths).Client }
Add-ToolBtn "Dir. Server" $C_GrayBtn 515 { Invoke-Item (Get-Paths).Server }

# LOG
$txtLog = New-Object System.Windows.Forms.TextBox; $txtLog.Location=New-Object System.Drawing.Point(15,530); $txtLog.Size=New-Object System.Drawing.Size(610,110); $txtLog.Multiline=$true; $txtLog.ScrollBars="Vertical"; $txtLog.ReadOnly=$true; $txtLog.BackColor=[System.Drawing.ColorTranslator]::FromHtml("#111111"); $txtLog.ForeColor=$C_Green; $txtLog.Font=$F_Console; $txtLog.BorderStyle="None"; $form.Controls.Add($txtLog)

# EVENTOS
$btnFolder.Add_Click({ Invoke-Item $scriptPath })
$btnDL.Add_Click({ Download-Mods })
$btnAuto.Add_Click({ $f=Find-GamePath; if($f){$txtPath.Text=$f; Save-Config}else{[System.Windows.Forms.MessageBox]::Show("No encontrado","Error","OK","Warning")} })
$btnBrw.Add_Click({ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog()-eq"OK"){$txtPath.Text=$d.SelectedPath; Save-Config} })
$btnAll.Add_Click({ for($i=0;$i -lt $clbMods.Items.Count;$i++){$clbMods.SetItemChecked($i,$true)} })
$btnNone.Add_Click({ for($i=0;$i -lt $clbMods.Items.Count;$i++){$clbMods.SetItemChecked($i,$false)} })
$btnRef.Add_Click({ Refresh-ModList; Log-Write "Lista refrescada." })

$btnUp.Add_Click({
    if ($clbMods.SelectedIndex -gt 0) {
        $i = $clbMods.SelectedIndex
        $item = $clbMods.Items[$i]
        $chk = $clbMods.GetItemChecked($i)
        $clbMods.Items.RemoveAt($i)
        $clbMods.Items.Insert($i - 1, $item)
        $clbMods.SetItemChecked($i - 1, $chk)
        $clbMods.SelectedIndex = $i - 1
    }
})

$btnDown.Add_Click({
    if (($clbMods.SelectedIndex -ge 0) -and ($clbMods.SelectedIndex -lt $clbMods.Items.Count - 1)) {
        $i = $clbMods.SelectedIndex
        $item = $clbMods.Items[$i]
        $chk = $clbMods.GetItemChecked($i)
        $clbMods.Items.RemoveAt($i)
        $clbMods.Items.Insert($i + 1, $item)
        $clbMods.SetItemChecked($i + 1, $chk)
        $clbMods.SelectedIndex = $i + 1
    }
})

$btnImport.Add_Click({
    $fI = New-Object System.Windows.Forms.Form; $fI.Text="Importar"; $fI.Size=New-Object System.Drawing.Size(400,300); $fI.StartPosition="CenterParent"; $fI.BackColor=$C_Bg; $fI.ForeColor="White"
    $tI = New-Object System.Windows.Forms.TextBox; $tI.Multiline=$true; $tI.Size=New-Object System.Drawing.Size(360,180); $tI.Location=New-Object System.Drawing.Point(10,10); $tI.BackColor=$C_Input; $tI.ForeColor="White"; $fI.Controls.Add($tI)
    $bI = New-Object System.Windows.Forms.Button; $bI.Text="OK"; $bI.Location=New-Object System.Drawing.Point(10,200); $bI.Size=New-Object System.Drawing.Size(360,40); $bI.BackColor=$C_Green; $bI.FlatStyle="Flat"; $fI.Controls.Add($bI)
    $bI.Add_Click({
        $ids=@(); $tI.Text -split "`n" | ForEach { if($_ -match "id=(\d+)"){$ids+=$Matches[1]} elseif($_ -match "^\d+$"){$ids+=$_.Trim()} }
        $txtModIds.Text = ($ids | Select -Unique) -join ","; $fI.Close()
    })
    $fI.ShowDialog()
})

$btnInst.Add_Click({
    if([string]::IsNullOrWhiteSpace($txtPath.Text)){return}
    
    $finalList = @()
    for ($i=0; $i -lt $clbMods.Items.Count; $i++) {
        if ($clbMods.GetItemChecked($i)) {
            # IMPORTANTE: Limpiamos el texto visual [INSTALADO...] para obtener el nombre real
            $cleanName = $clbMods.Items[$i] -replace "   \[INSTALADO.*\]", ""
            $finalList += $cleanName
        }
    }

    if($finalList.Count -eq 0){return}
    $paths = Get-Paths
    $progBar.Maximum = if($chkClient.Checked -and $chkServer.Checked){$finalList.Count*2}else{$finalList.Count}
    $progBar.Value = 0
    
    $modTxtList = @(); foreach($s in $finalList){$modTxtList+="*$s"}

    function Inst($dst) {
        if(-not(Test-Path $dst)){New-Item -ItemType Directory -Path $dst -Force|Out-Null}
        foreach($s in $finalList){
            Copy-Item "$scriptPath\$s" $dst -Force
            if($chkSig.Checked){New-Item -Path "$dst\$([io.path]::GetFileNameWithoutExtension($s)).sig" -ItemType File -Force|Out-Null}
            $progBar.PerformStep()
        }
        $modTxtList | Set-Content "$dst\modlist.txt"
    }
    Log-Write "Instalando en orden..."
    if($chkClient.Checked){Inst $paths.Client; Log-Write "Cliente OK"}
    if($chkServer.Checked){Inst $paths.Server; Log-Write "Server OK"}
    
    Refresh-ModList
    [System.Windows.Forms.MessageBox]::Show("Terminado","OK","OK","Information"); $progBar.Value=0
})

$form.Add_Load({ Load-Config })
$form.ShowDialog() | Out-Null