# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Gustavo
#
# 1155 - menu de tweaks para Windows (versao PowerShell).
# Software livre sob licenca MIT. Veja o arquivo LICENSE.
# USE POR SUA CONTA E RISCO: este script altera o registro e configuracoes do Windows.
#
# Uso rapido (Windows PowerShell):
#   irm https://raw.githubusercontent.com/andriolimerinogustavo-hue/1155-otimiza-o/main/1155.ps1 | iex
#
# Este arquivo usa so caracteres ASCII (sem acentos) de proposito, para funcionar
# em qualquer versao do PowerShell, inclusive quando executado via "irm | iex".
# O backup usa o mesmo formato da versao em Python (%APPDATA%\TweaksMenu\backup.json),
# entao a opcao "Reverter" de uma versao desfaz alteracoes feitas pela outra.

$script:UrlRaw     = 'https://raw.githubusercontent.com/andriolimerinogustavo-hue/1155-otimiza-o/main/1155.ps1'
$script:PastaDados = Join-Path $env:APPDATA 'TweaksMenu'
$script:ArqBackup  = Join-Path $script:PastaDados 'backup.json'
$script:GuidRegex  = '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'
$script:SubUsb     = '2a737441-1930-4402-8d77-b2bebba308a3'
$script:ConfigUsb  = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'

# ---------------------------------------------------------------- mensagens
function Write-Ok([string]$Texto) {
    Write-Host '  ' -NoNewline
    Write-Host 'OK' -ForegroundColor Green -NoNewline
    Write-Host " $Texto"
}

function Write-Erro([string]$Texto) {
    Write-Host "  $Texto" -ForegroundColor Red
}

function Write-Aviso([string]$Texto) {
    Write-Host "  $Texto" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- banner
$script:Letras = @{
    '1' = @('  #  ', ' ##  ', '  #  ', '  #  ', ' ### ')
    '5' = @('#####', '#    ', '#### ', '    #', '#### ')
}

function Show-Banner {
    for ($i = 0; $i -lt 5; $i++) {
        $linha = ($script:Letras['1'][$i], $script:Letras['1'][$i], $script:Letras['5'][$i], $script:Letras['5'][$i]) -join '   '
        Write-Host ('      ' + $linha) -ForegroundColor Blue
    }
}

# ---------------------------------------------------------------- utilidades
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Backup {
    $dados = [ordered]@{}
    if (Test-Path -LiteralPath $script:ArqBackup) {
        try {
            $obj = Get-Content -LiteralPath $script:ArqBackup -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $obj.PSObject.Properties) { $dados[$prop.Name] = $prop.Value }
        } catch { }
    }
    return $dados
}

function Save-Backup($Dados) {
    if (-not (Test-Path -LiteralPath $script:PastaDados)) {
        New-Item -ItemType Directory -Path $script:PastaDados -Force | Out-Null
    }
    $json = $Dados | ConvertTo-Json -Depth 4
    # UTF-8 sem BOM, para o Python tambem conseguir ler este arquivo
    [System.IO.File]::WriteAllText($script:ArqBackup, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-RegRoot([string]$Raiz) {
    if ($Raiz -eq 'HKLM') {
        return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    }
    return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Registry64)
}

function Set-Reg {
    # Grava um valor no registro guardando o valor original para reverter.
    param(
        [string]$Raiz,
        [string]$Caminho,
        [string]$Nome,
        $Valor,
        [string]$Tipo = 'DWord',
        [switch]$SoSeExistir
    )
    $root = Get-RegRoot $Raiz

    if ($SoSeExistir) {
        $teste = $root.OpenSubKey($Caminho)
        if (-not $teste) {
            Write-Aviso "- chave nao existe neste Windows, ignorado: $Nome"
            return
        }
        $teste.Close()
    }

    $backup = Get-Backup
    $chave = "$Raiz\$Caminho\$Nome"
    if (-not $backup.Contains($chave)) {
        $entrada = $null
        $k = $root.OpenSubKey($Caminho)
        if ($k) {
            $antigo = $k.GetValue($Nome)
            if ($null -ne $antigo) {
                $entrada = [ordered]@{ valor = $antigo; tipo = [int]$k.GetValueKind($Nome) }
            }
            $k.Close()
        }
        $backup[$chave] = $entrada
        Save-Backup $backup
    }

    try {
        $k = $root.CreateSubKey($Caminho)
        if ($Tipo -eq 'String') {
            $k.SetValue($Nome, [string]$Valor, [Microsoft.Win32.RegistryValueKind]::String)
        } else {
            $k.SetValue($Nome, [int]$Valor, [Microsoft.Win32.RegistryValueKind]::DWord)
        }
        $k.Close()
        Write-Ok "$Nome = $Valor"
    } catch {
        if ($_.Exception -is [UnauthorizedAccessException] -or $_.Exception -is [System.Security.SecurityException]) {
            Write-Erro "Sem permissao para $Nome (execute como administrador)"
        } else {
            Write-Erro "Falhou em ${Nome}: $($_.Exception.Message)"
        }
    }
}

function Get-PlanoAtivo {
    $saida = (powercfg /getactivescheme 2>&1) | Out-String
    if ($saida -match $script:GuidRegex) { return $matches[0] }
    return $null
}

# ---------------------------------------------------------------- tweaks
function Set-ModoJogo {
    $p = 'Software\Microsoft\GameBar'
    Set-Reg 'HKCU' $p 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU' $p 'AllowAutoGameMode' 1
}

function Set-PlanoAltoDesempenho {
    $guidAlto = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $atual = Get-PlanoAtivo
    $backup = Get-Backup
    if ($atual -and -not $backup.Contains('_plano_energia')) {
        $backup['_plano_energia'] = $atual
        Save-Backup $backup
    }
    powercfg -setactive $guidAlto 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $saida = (powercfg -duplicatescheme $guidAlto 2>&1) | Out-String
        $falhou = $true
        if ($saida -match $script:GuidRegex) {
            $novo = $matches[0]
            powercfg -setactive $novo 2>&1 | Out-Null
            $falhou = ($LASTEXITCODE -ne 0)
        }
        if ($falhou) {
            Write-Erro 'Nao foi possivel ativar o plano Alto desempenho.'
            return
        }
    }
    Write-Ok 'plano de energia: Alto desempenho'
}

function Disable-GameDvr {
    Set-Reg 'HKCU' 'System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
}

function Set-EfeitosVisuais {
    Set-Reg 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
    Set-Reg 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-Reg 'HKCU' 'Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Write-Aviso 'Faca logoff/login para aplicar.'
}

function Set-AgendamentoGpu {
    Set-Reg 'HKLM' 'SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    Write-Aviso 'Reinicie o PC para aplicar. Se piorar, use a opcao Reverter.'
}

function Set-MouseSemAceleracao {
    $p = 'Control Panel\Mouse'
    Set-Reg 'HKCU' $p 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU' $p 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU' $p 'MouseThreshold2' '0' 'String'
    Write-Aviso 'Faca logoff/login para aplicar.'
}

function Disable-PresenceWriter {
    Set-Reg 'HKLM' 'SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter' 'ActivationType' 0 -SoSeExistir
}

function Set-TecladoRepeticaoRapida {
    $p = 'Control Panel\Keyboard'
    Set-Reg 'HKCU' $p 'KeyboardDelay' '0' 'String'    # atraso minimo
    Set-Reg 'HKCU' $p 'KeyboardSpeed' '31' 'String'   # taxa maxima
    try {  # aplica na hora, sem precisar de logoff
        if (-not ('Win32Spi1155.Nativo' -as [type])) {
            Add-Type -Namespace Win32Spi1155 -Name Nativo -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);'
        }
        # SPI_SETKEYBOARDDELAY = 0x0017, SPI_SETKEYBOARDSPEED = 0x000B, flags = UPDATEINIFILE | SENDCHANGE
        [void][Win32Spi1155.Nativo]::SystemParametersInfo(0x0017, 0, [IntPtr]::Zero, 3)
        [void][Win32Spi1155.Nativo]::SystemParametersInfo(0x000B, 31, [IntPtr]::Zero, 3)
    } catch {
        Write-Aviso 'Faca logoff/login para aplicar.'
    }
}

function Disable-TeclasAderentesFiltro {
    $base = 'Control Panel\Accessibility'
    # 506 e 122 = recurso desligado e atalho de ativacao (Shift 5x / Shift direito 8s) desativado
    Set-Reg 'HKCU' "$base\StickyKeys" 'Flags' '506' 'String'
    Set-Reg 'HKCU' "$base\Keyboard Response" 'Flags' '122' 'String'
    Write-Aviso 'Faca logoff/login para aplicar.'
}

function Disable-UsbSuspensao {
    $guid = Get-PlanoAtivo
    if (-not $guid) {
        Write-Erro 'Nao foi possivel identificar o plano de energia ativo.'
        return
    }
    powercfg /setacvalueindex $guid $script:SubUsb $script:ConfigUsb 0 2>&1 | Out-Null
    $r1 = $LASTEXITCODE
    powercfg /setdcvalueindex $guid $script:SubUsb $script:ConfigUsb 0 2>&1 | Out-Null
    $r2 = $LASTEXITCODE
    if ($r1 -ne 0 -or $r2 -ne 0) {
        Write-Erro 'Falhou. Execute como administrador.'
        return
    }
    powercfg /setactive $guid 2>&1 | Out-Null
    $backup = Get-Backup
    $backup['_usb_suspend'] = $guid
    Save-Backup $backup
    Write-Ok 'suspensao seletiva de USB desativada no plano atual'
}

function Invoke-AplicarTudo {
    foreach ($item in $script:Otimizacoes) {
        Write-Host "> $($item.Rotulo)" -ForegroundColor Magenta
        & $item.Acao
    }
}

# ---------------------------------------------------------------- ferramentas
function Open-MsConfig { Start-Process 'msconfig.exe' }

function Open-Inicializacao { Start-Process 'ms-settings:startupapps' }

function Open-GerenciadorTarefas { Start-Process 'taskmgr.exe' }

function Clear-Temp {
    $pastas = @($env:TEMP, 'C:\Windows\Temp')
    $removidos = 0
    foreach ($pasta in $pastas) {
        if (-not $pasta -or -not (Test-Path -LiteralPath $pasta -PathType Container)) { continue }
        foreach ($item in (Get-ChildItem -LiteralPath $pasta -Force -ErrorAction SilentlyContinue)) {
            try {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    # link simbolico: remove so o link, nunca o conteudo apontado
                    if ($item.PSIsContainer) { [IO.Directory]::Delete($item.FullName) } else { [IO.File]::Delete($item.FullName) }
                } else {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                $removidos++
            } catch { }   # arquivo em uso, normal
        }
    }
    Write-Ok "$removidos itens temporarios removidos"
}

function Install-Afterburner {
    $urlMsi = 'https://www.msi.com/support/technical_details/VGA_MSI_Utility_AfterBurner'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Aviso 'O winget nao foi encontrado neste Windows.'
        Write-Host '  Abrindo a pagina oficial da MSI para baixar manualmente...'
        Start-Process $urlMsi
        return
    }
    Write-Host "  Instalando MSI Afterburner pelo winget (precisa de internet)...`n"
    winget install --id Guru3D.Afterburner --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host ''
        Write-Ok 'MSI Afterburner instalado.'
        Write-Host '  Para desinstalar: Configuracoes > Aplicativos > Aplicativos instalados.'
    } else {
        Write-Host ''
        Write-Erro 'A instalacao nao foi concluida.'
        Write-Host '  Abrindo a pagina oficial da MSI para baixar manualmente...'
        Start-Process $urlMsi
    }
}

function Invoke-DesativarSeguranca {
    Write-Host '  ATENCAO: isto desliga o Defender (protecao em tempo real), o Firewall e o SmartScreen.' -ForegroundColor Red
    Write-Host '  Seu PC ficara exposto a virus e ataques, principalmente online.'
    if (-not (Test-Admin)) {
        Write-Erro 'Execute como administrador.'
        return
    }
    $resp = (Read-Host '  Digite CONFIRMAR para continuar').Trim()
    if ($resp -cne 'CONFIRMAR') {
        Write-Host '  Cancelado.'
        return
    }

    # A Protecao contra Adulteracao do Windows bloqueia estas mudancas; so o usuario pode desliga-la.
    $tamper = $false
    try { $tamper = [bool](Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected } catch { }
    if ($tamper) {
        Write-Host ''
        Write-Aviso 'A Protecao contra Adulteracao esta ligada e bloqueia a alteracao.'
        Write-Host '  Desligue manualmente: Seguranca do Windows > Protecao contra virus e ameacas >'
        Write-Host '  Gerenciar configuracoes > Protecao contra Adulteracao > Desativada.'
        Write-Host '  Depois rode esta opcao novamente.'
        return
    }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
            -DisableIOAVProtection $true -DisableScriptScanning $true -DisableBlockAtFirstSeen $true -ErrorAction Stop
        Write-Ok 'Defender em tempo real desativado'
    } catch {
        Write-Erro 'Falhou ao desativar o Defender'
    }
    netsh advfirewall set allprofiles state off 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Firewall desativado' } else { Write-Erro 'Falhou ao desativar o Firewall' }
    Set-Reg 'HKLM' 'SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 0
    Set-Reg 'HKLM' 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'Off' 'String'
    Write-Host ''
    Write-Aviso "Para voltar ao normal use a opcao 'Reativar seguranca'."
}

function Invoke-ReativarSeguranca {
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false `
            -DisableIOAVProtection $false -DisableScriptScanning $false -DisableBlockAtFirstSeen $false -ErrorAction Stop
        Write-Ok 'Defender reativado'
    } catch {
        Write-Erro 'Falhou ao reativar o Defender'
    }
    netsh advfirewall set allprofiles state on 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Firewall reativado' } else { Write-Erro 'Falhou ao reativar o Firewall' }
    try {
        $k = (Get-RegRoot 'HKLM').OpenSubKey('SOFTWARE\Policies\Microsoft\Windows\System', $true)
        if ($k) { $k.DeleteValue('EnableSmartScreen', $false); $k.Close() }
    } catch { }
    try {
        $k = (Get-RegRoot 'HKLM').OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer', $true)
        $k.SetValue('SmartScreenEnabled', 'Warn', [Microsoft.Win32.RegistryValueKind]::String)
        $k.Close()
        Write-Ok 'SmartScreen reativado'
    } catch {
        Write-Erro 'Falhou ao reativar o SmartScreen'
    }
}

function Add-ExclusaoDefender {
    $pasta = (Read-Host '  Caminho da pasta do jogo (ex.: C:\Games)').Trim().Trim('"')
    if (-not (Test-Path -LiteralPath $pasta -PathType Container)) {
        Write-Erro 'Pasta nao encontrada.'
        return
    }
    try {
        Add-MpPreference -ExclusionPath $pasta -ErrorAction Stop
        Write-Ok 'pasta excluida da verificacao do Defender'
    } catch {
        Write-Erro 'Falhou (execute como administrador)'
    }
}

function New-PontoRestauracao {
    Write-Host '  Criando ponto de restauracao (pode levar alguns segundos)...'
    try {
        Checkpoint-Computer -Description 'TweaksMenu' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningVariable aviso -WarningAction SilentlyContinue
        if ($aviso) { throw 'aviso' }
        Write-Ok 'ponto de restauracao criado'
    } catch {
        Write-Aviso 'Nao foi possivel criar. A Protecao do Sistema pode estar desligada,'
        Write-Host '  ou o Windows ja criou um ponto nas ultimas 24 horas.'
    }
}

function Undo-Alteracoes {
    $backup = Get-Backup
    if ($backup.Count -eq 0) {
        Write-Host '  Nada para reverter.'
        return
    }
    foreach ($chave in @($backup.Keys)) {
        $antigo = $backup[$chave]
        if ($chave -eq '_usb_suspend') {
            powercfg /setacvalueindex $antigo $script:SubUsb $script:ConfigUsb 1 2>&1 | Out-Null
            powercfg /setdcvalueindex $antigo $script:SubUsb $script:ConfigUsb 1 2>&1 | Out-Null
            Write-Ok 'suspensao seletiva de USB restaurada'
            continue
        }
        if ($chave -eq '_plano_energia') {
            powercfg -setactive $antigo 2>&1 | Out-Null
            Write-Ok 'plano de energia restaurado'
            continue
        }
        $partes = $chave -split '\\', 2
        $raiz = $partes[0]
        $resto = $partes[1]
        $idx = $resto.LastIndexOf('\')
        $caminho = $resto.Substring(0, $idx)
        $nome = $resto.Substring($idx + 1)
        try {
            $root = Get-RegRoot $raiz
            if ($null -eq $antigo) {
                $k = $root.OpenSubKey($caminho, $true)
                if ($k) { $k.DeleteValue($nome, $false); $k.Close() }
            } else {
                $tipo = [Microsoft.Win32.RegistryValueKind][int]$antigo.tipo
                $valor = $antigo.valor
                if ($tipo -eq [Microsoft.Win32.RegistryValueKind]::DWord) { $valor = [int]$valor }
                elseif ($tipo -eq [Microsoft.Win32.RegistryValueKind]::String) { $valor = [string]$valor }
                $k = $root.CreateSubKey($caminho)
                $k.SetValue($nome, $valor, $tipo)
                $k.Close()
            }
            Write-Ok "restaurado: $nome"
        } catch {
            Write-Erro "Falhou ${nome}: $($_.Exception.Message)"
        }
    }
    Remove-Item -LiteralPath $script:ArqBackup -Force -ErrorAction SilentlyContinue
    Write-Aviso 'Reinicie o PC para concluir.'
}

# ---------------------------------------------------------------- menu
$script:Otimizacoes = @(
    @{ Num = '1';  Rotulo = 'Modo de Jogo ligado';              Acao = { Set-ModoJogo } },
    @{ Num = '2';  Rotulo = 'Plano Alto Desempenho';            Acao = { Set-PlanoAltoDesempenho } },
    @{ Num = '3';  Rotulo = 'Desativar Game DVR';               Acao = { Disable-GameDvr } },
    @{ Num = '4';  Rotulo = 'Efeitos visuais leves';            Acao = { Set-EfeitosVisuais } },
    @{ Num = '5';  Rotulo = 'GPU Scheduling (HAGS)';            Acao = { Set-AgendamentoGpu } },
    @{ Num = '6';  Rotulo = 'Diminuir Input Lag (mouse)';       Acao = { Set-MouseSemAceleracao } },
    @{ Num = '7';  Rotulo = 'Desativar PresenceWriter';         Acao = { Disable-PresenceWriter } },
    @{ Num = '8';  Rotulo = 'Teclado: repeticao rapida';        Acao = { Set-TecladoRepeticaoRapida } },
    @{ Num = '9';  Rotulo = 'Desligar Teclas Aderentes/Filtro'; Acao = { Disable-TeclasAderentesFiltro } },
    @{ Num = '10'; Rotulo = 'USB sem suspensao seletiva';       Acao = { Disable-UsbSuspensao } }
)

$script:Paginas = @(
    @{
        Titulo = 'Pagina 1 - Otimizacoes'
        Itens  = @($script:Otimizacoes + @(
            @{ Num = '11'; Rotulo = 'Aplicar tudo (1 a 10)'; Acao = { Invoke-AplicarTudo } }
        ))
    },
    @{
        Titulo = 'Pagina 2 - Ferramentas'
        Itens  = @(
            @{ Num = '12'; Rotulo = 'MSConfig';                          Acao = { Open-MsConfig } },
            @{ Num = '13'; Rotulo = 'AutoRuns (apps de inicializacao)';  Acao = { Open-Inicializacao } },
            @{ Num = '14'; Rotulo = 'Gerenciador de Tarefas';            Acao = { Open-GerenciadorTarefas } },
            @{ Num = '15'; Rotulo = 'Limpar arquivos temporarios';       Acao = { Clear-Temp } },
            @{ Num = '16'; Rotulo = 'Criar ponto de restauracao';        Acao = { New-PontoRestauracao } },
            @{ Num = '17'; Rotulo = 'Reverter alteracoes';               Acao = { Undo-Alteracoes } },
            @{ Num = '18'; Rotulo = 'Instalar MSI Afterburner';          Acao = { Install-Afterburner } },
            @{ Num = '19'; Rotulo = 'Excluir pasta de jogos do Defender'; Acao = { Add-ExclusaoDefender } },
            @{ Num = '20'; Rotulo = 'DESATIVAR seguranca do Windows';    Acao = { Invoke-DesativarSeguranca } },
            @{ Num = '21'; Rotulo = 'Reativar seguranca do Windows';     Acao = { Invoke-ReativarSeguranca } }
        )
    }
)

function Show-Menu([int]$Pagina) {
    Clear-Host
    Write-Host ''
    Show-Banner
    Write-Host ''
    $pontos = '.' * 78
    Write-Host $pontos -ForegroundColor Magenta
    $titulo = $script:Paginas[$Pagina].Titulo
    $itens = $script:Paginas[$Pagina].Itens
    for ($i = 0; $i -lt $itens.Count; $i += 2) {
        $fim = [Math]::Min($i + 1, $itens.Count - 1)
        for ($j = $i; $j -le $fim; $j++) {
            $it = $itens[$j]
            $txt = (' ' + $it.Rotulo).PadRight(44)
            Write-Host '  ' -NoNewline
            Write-Host "[$($it.Num)]" -ForegroundColor Magenta -NoNewline
            Write-Host $txt -NoNewline
        }
        Write-Host ''
    }
    Write-Host ''
    $outra = if ($Pagina -eq 0) { 2 } else { 1 }
    Write-Host '  ' -NoNewline
    Write-Host '[X]' -ForegroundColor Red -NoNewline
    Write-Host " Pagina $outra      " -ForegroundColor Yellow -NoNewline
    Write-Host '[0]' -ForegroundColor Red -NoNewline
    Write-Host ' Sair' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  $titulo" -ForegroundColor Yellow
    Write-Host $pontos -ForegroundColor Magenta
    Write-Host '~by gustavo~'.PadLeft(78) -ForegroundColor Blue
    if (-not (Test-Admin)) {
        Write-Host '  Aviso: nao esta como administrador. Algumas opcoes vao falhar.' -ForegroundColor Red
    }
}

function Start-Menu1155 {
    # Se nao estiver como administrador, reabre pedindo permissao (UAC).
    if (-not (Test-Admin)) {
        Write-Host 'Pedindo permissao de administrador...'
        try {
            if ($PSCommandPath) {
                Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
            } else {
                $cmd = "irm '$($script:UrlRaw)' | iex"
                Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd)
            }
            return   # a nova janela (admin) assume
        } catch {
            Write-Erro 'Permissao de administrador negada. O programa precisa dela para funcionar.'
            Read-Host 'Pressione Enter para sair...' | Out-Null
            return
        }
    }

    try { $Host.UI.RawUI.WindowTitle = '1155 by gustavo' } catch { }

    $pagina = 0
    while ($true) {
        Show-Menu $pagina
        $op = (Read-Host "`n  Escolha").Trim().ToLower()
        if ($op -eq '0') { break }
        if ($op -eq 'x') { $pagina = 1 - $pagina; continue }
        $acao = $null
        foreach ($pg in $script:Paginas) {
            foreach ($it in $pg.Itens) {
                if ($it.Num -eq $op) { $acao = $it.Acao }
            }
        }
        if (-not $acao) { continue }
        Write-Host ''
        try { & $acao } catch { Write-Erro "Falhou: $($_.Exception.Message)" }
        Read-Host "`n  Pressione Enter para voltar ao menu..." | Out-Null
    }
}

Start-Menu1155
