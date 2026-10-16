# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Gustavo
"""1155 - menu de tweaks para Windows (console).

Software livre sob licença MIT. Veja o arquivo LICENSE.
USE POR SUA CONTA E RISCO: este programa altera o registro e configurações do Windows.
"""
import ctypes
import json
import os
import re
import shutil
import subprocess
import sys
import winreg

os.system("")  # ativa cores ANSI no console do Windows

AZUL, MAG, AMA = "\033[94m", "\033[95m", "\033[93m"
VERM, VERDE, RST = "\033[91m", "\033[92m", "\033[0m"

ROOTS = {"HKCU": winreg.HKEY_CURRENT_USER, "HKLM": winreg.HKEY_LOCAL_MACHINE}
PASTA_DADOS = os.path.join(os.environ.get("APPDATA", "."), "TweaksMenu")
ARQ_BACKUP = os.path.join(PASTA_DADOS, "backup.json")

# ---------------------------------------------------------------- banner
LETRAS = {
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  "],
    "W": ["#   #", "#   #", "# # #", "## ##", "#   #"],
    "E": ["#####", "#    ", "#### ", "#    ", "#####"],
    "A": [" ### ", "#   #", "#####", "#   #", "#   #"],
    "K": ["#   #", "#  # ", "###  ", "#  # ", "#   #"],
    "S": [" ####", "#    ", " ### ", "    #", "#### "],
    "1": ["  #  ", " ##  ", "  #  ", "  #  ", " ### "],
    "5": ["#####", "#    ", "#### ", "    #", "#### "],
}


def banner():
    linhas = []
    for i in range(5):
        linhas.append("   ".join(LETRAS[c][i] for c in "1155"))
    return "\n".join(AZUL + "      " + l + RST for l in linhas)


# ---------------------------------------------------------------- utilidades
def eh_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def carregar_backup():
    try:
        with open(ARQ_BACKUP, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def salvar_backup(dados):
    os.makedirs(PASTA_DADOS, exist_ok=True)
    with open(ARQ_BACKUP, "w", encoding="utf-8") as f:
        json.dump(dados, f, indent=2)


def definir_reg(raiz, caminho, nome, valor, tipo=winreg.REG_DWORD, so_se_existir=False):
    """Grava um valor no registro guardando o valor original para reverter."""
    if so_se_existir:
        try:
            winreg.CloseKey(winreg.OpenKey(ROOTS[raiz], caminho))
        except FileNotFoundError:
            print(f"  {AMA}-{RST} chave não existe neste Windows, ignorado: {nome}")
            return
    backup = carregar_backup()
    chave = f"{raiz}\\{caminho}\\{nome}"
    if chave not in backup:
        try:
            with winreg.OpenKey(ROOTS[raiz], caminho, 0, winreg.KEY_READ) as k:
                v, t = winreg.QueryValueEx(k, nome)
                backup[chave] = {"valor": v, "tipo": t}
        except FileNotFoundError:
            backup[chave] = None
        salvar_backup(backup)
    try:
        with winreg.CreateKeyEx(ROOTS[raiz], caminho, 0, winreg.KEY_SET_VALUE) as k:
            winreg.SetValueEx(k, nome, 0, tipo, valor)
        print(f"  {VERDE}OK{RST} {nome} = {valor}")
    except PermissionError:
        print(f"  {VERM}Sem permissão{RST} para {nome} (execute como administrador)")


def rodar(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, shell=True)


# ---------------------------------------------------------------- tweaks
def modo_jogo():
    p = r"Software\Microsoft\GameBar"
    definir_reg("HKCU", p, "AutoGameModeEnabled", 1)
    definir_reg("HKCU", p, "AllowAutoGameMode", 1)


def plano_alto_desempenho():
    guid_alto = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    atual = rodar("powercfg /getactivescheme").stdout
    m = re.search(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", atual)
    backup = carregar_backup()
    if m and "_plano_energia" not in backup:
        backup["_plano_energia"] = m.group(0)
        salvar_backup(backup)
    if rodar(f"powercfg -setactive {guid_alto}").returncode != 0:
        saida = rodar(f"powercfg -duplicatescheme {guid_alto}").stdout
        m2 = re.search(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", saida)
        if not m2 or rodar(f"powercfg -setactive {m2.group(0)}").returncode != 0:
            print(f"  {VERM}Não foi possível ativar o plano Alto desempenho.{RST}")
            return
    print(f"  {VERDE}OK{RST} plano de energia: Alto desempenho")


def desativar_game_dvr():
    definir_reg("HKCU", r"System\GameConfigStore", "GameDVR_Enabled", 0)
    definir_reg("HKCU", r"Software\Microsoft\Windows\CurrentVersion\GameDVR", "AppCaptureEnabled", 0)


def efeitos_visuais():
    definir_reg("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
                "VisualFXSetting", 2)
    definir_reg("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "EnableTransparency", 0)
    definir_reg("HKCU", r"Control Panel\Desktop\WindowMetrics", "MinAnimate", "0", winreg.REG_SZ)
    print(f"  {AMA}Faça logoff/login para aplicar.{RST}")


def agendamento_gpu():
    definir_reg("HKLM", r"SYSTEM\CurrentControlSet\Control\GraphicsDrivers", "HwSchMode", 2)
    print(f"  {AMA}Reinicie o PC para aplicar. Se piorar, use a opção Reverter.{RST}")


def mouse_sem_aceleracao():
    p = r"Control Panel\Mouse"
    definir_reg("HKCU", p, "MouseSpeed", "0", winreg.REG_SZ)
    definir_reg("HKCU", p, "MouseThreshold1", "0", winreg.REG_SZ)
    definir_reg("HKCU", p, "MouseThreshold2", "0", winreg.REG_SZ)
    print(f"  {AMA}Faça logoff/login para aplicar.{RST}")


def presence_writer():
    definir_reg(
        "HKLM",
        r"SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter",
        "ActivationType", 0, so_se_existir=True,
    )


def teclado_repeticao_rapida():
    p = r"Control Panel\Keyboard"
    definir_reg("HKCU", p, "KeyboardDelay", "0", winreg.REG_SZ)    # atraso mínimo
    definir_reg("HKCU", p, "KeyboardSpeed", "31", winreg.REG_SZ)   # taxa máxima
    try:  # aplica na hora, sem precisar de logoff
        SPI_SETKEYBOARDDELAY, SPI_SETKEYBOARDSPEED = 0x0017, 0x000B
        flags = 0x01 | 0x02  # SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
        ctypes.windll.user32.SystemParametersInfoW(SPI_SETKEYBOARDDELAY, 0, None, flags)
        ctypes.windll.user32.SystemParametersInfoW(SPI_SETKEYBOARDSPEED, 31, None, flags)
    except Exception:
        print(f"  {AMA}Faça logoff/login para aplicar.{RST}")


def desligar_teclas_aderentes_filtro():
    base = r"Control Panel\Accessibility"
    # 506 e 122 = recurso desligado e atalho de ativação (Shift 5x / Shift direito 8s) desativado
    definir_reg("HKCU", base + r"\StickyKeys", "Flags", "506", winreg.REG_SZ)
    definir_reg("HKCU", base + r"\Keyboard Response", "Flags", "122", winreg.REG_SZ)
    print(f"  {AMA}Faça logoff/login para aplicar.{RST}")


def usb_sem_suspensao():
    sub_usb = "2a737441-1930-4402-8d77-b2bebba308a3"
    config = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    atual = rodar("powercfg /getactivescheme").stdout
    m = re.search(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", atual)
    if not m:
        print(f"  {VERM}Não foi possível identificar o plano de energia ativo.{RST}")
        return
    guid = m.group(0)
    r1 = rodar(f"powercfg /setacvalueindex {guid} {sub_usb} {config} 0")
    r2 = rodar(f"powercfg /setdcvalueindex {guid} {sub_usb} {config} 0")
    if r1.returncode != 0 or r2.returncode != 0:
        print(f"  {VERM}Falhou.{RST} Execute como administrador.")
        return
    rodar(f"powercfg /setactive {guid}")
    backup = carregar_backup()
    backup["_usb_suspend"] = guid
    salvar_backup(backup)
    print(f"  {VERDE}OK{RST} suspensão seletiva de USB desativada no plano atual")


def aplicar_tudo():
    for f in (modo_jogo, plano_alto_desempenho, desativar_game_dvr, efeitos_visuais,
              agendamento_gpu, mouse_sem_aceleracao, presence_writer,
              teclado_repeticao_rapida, desligar_teclas_aderentes_filtro, usb_sem_suspensao):
        print(f"{MAG}> {f.__name__}{RST}")
        f()


def abrir_msconfig():
    subprocess.Popen("msconfig.exe", shell=True)


def abrir_inicializacao():
    os.startfile("ms-settings:startupapps")


def abrir_gerenciador():
    subprocess.Popen("taskmgr.exe", shell=True)


def limpar_temp():
    pastas = [os.environ.get("TEMP", ""), r"C:\Windows\Temp"]
    removidos = 0
    for pasta in pastas:
        if not pasta or not os.path.isdir(pasta):
            continue
        for nome in os.listdir(pasta):
            caminho = os.path.join(pasta, nome)
            try:
                if os.path.isdir(caminho) and not os.path.islink(caminho):
                    shutil.rmtree(caminho)
                else:
                    os.remove(caminho)
                removidos += 1
            except Exception:
                pass  # arquivo em uso, normal
    print(f"  {VERDE}OK{RST} {removidos} itens temporários removidos")


def instalar_afterburner():
    if rodar("winget --version").returncode != 0:
        print(f"  {AMA}O winget não foi encontrado neste Windows.{RST}")
        print("  Abrindo a página oficial da MSI para baixar manualmente...")
        os.startfile("https://www.msi.com/support/technical_details/VGA_MSI_Utility_AfterBurner")
        return
    print("  Instalando MSI Afterburner pelo winget (precisa de internet)...\n")
    r = subprocess.run(
        "winget install --id Guru3D.Afterburner --exact "
        "--accept-package-agreements --accept-source-agreements",
        shell=True,
    )
    if r.returncode == 0:
        print(f"\n  {VERDE}OK{RST} MSI Afterburner instalado.")
        print("  Para desinstalar: Configurações > Aplicativos > Aplicativos instalados.")
    else:
        print(f"\n  {VERM}A instalação não foi concluída.{RST}")
        print("  Abrindo a página oficial da MSI para baixar manualmente...")
        os.startfile("https://www.msi.com/support/technical_details/VGA_MSI_Utility_AfterBurner")


def _ps(cmd):
    return rodar(f'powershell -NoProfile -Command "{cmd}"')


def desativar_seguranca():
    print(f"  {VERM}ATENÇÃO:{RST} isto desliga o Defender (proteção em tempo real), o Firewall e o SmartScreen.")
    print("  Seu PC ficará exposto a vírus e ataques, principalmente online.")
    if not eh_admin():
        print(f"  {VERM}Execute como administrador.{RST}")
        return
    if input("  Digite CONFIRMAR para continuar: ").strip() != "CONFIRMAR":
        print("  Cancelado.")
        return

    # A Proteção contra Adulteração do Windows bloqueia estas mudanças; só o usuário pode desligá-la.
    if _ps("(Get-MpComputerStatus).IsTamperProtected").stdout.strip().lower() == "true":
        print(f"\n  {AMA}A Proteção contra Adulteração está ligada e bloqueia a alteração.{RST}")
        print("  Desligue manualmente: Segurança do Windows > Proteção contra vírus e ameaças >")
        print("  Gerenciar configurações > Proteção contra Adulteração > Desativada.")
        print("  Depois rode esta opção novamente.")
        return

    r = _ps("Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true "
            "-DisableIOAVProtection $true -DisableScriptScanning $true -DisableBlockAtFirstSeen $true")
    print(f"  {VERDE}OK{RST} Defender em tempo real desativado" if r.returncode == 0
          else f"  {VERM}Falhou{RST} ao desativar o Defender")
    r = rodar("netsh advfirewall set allprofiles state off")
    print(f"  {VERDE}OK{RST} Firewall desativado" if r.returncode == 0
          else f"  {VERM}Falhou{RST} ao desativar o Firewall")
    definir_reg("HKLM", r"SOFTWARE\Policies\Microsoft\Windows\System", "EnableSmartScreen", 0)
    definir_reg("HKLM", r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer",
                "SmartScreenEnabled", "Off", winreg.REG_SZ)
    print(f"\n  {AMA}Para voltar ao normal use a opção 'Reativar segurança'.{RST}")


def reativar_seguranca():
    r = _ps("Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false "
            "-DisableIOAVProtection $false -DisableScriptScanning $false -DisableBlockAtFirstSeen $false")
    print(f"  {VERDE}OK{RST} Defender reativado" if r.returncode == 0
          else f"  {VERM}Falhou{RST} ao reativar o Defender")
    r = rodar("netsh advfirewall set allprofiles state on")
    print(f"  {VERDE}OK{RST} Firewall reativado" if r.returncode == 0
          else f"  {VERM}Falhou{RST} ao reativar o Firewall")
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Policies\Microsoft\Windows\System",
                            0, winreg.KEY_SET_VALUE) as k:
            winreg.DeleteValue(k, "EnableSmartScreen")
    except OSError:
        pass
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer",
                            0, winreg.KEY_SET_VALUE) as k:
            winreg.SetValueEx(k, "SmartScreenEnabled", 0, winreg.REG_SZ, "Warn")
        print(f"  {VERDE}OK{RST} SmartScreen reativado")
    except OSError:
        print(f"  {VERM}Falhou{RST} ao reativar o SmartScreen")


def excluir_pasta_defender():
    pasta = input("  Caminho da pasta do jogo (ex.: C:\\Games): ").strip().strip('"')
    if not os.path.isdir(pasta):
        print(f"  {VERM}Pasta não encontrada.{RST}")
        return
    pasta_ps = pasta.replace("'", "''")  # escapa aspas simples para o PowerShell
    r = _ps(f"Add-MpPreference -ExclusionPath '{pasta_ps}'")
    print(f"  {VERDE}OK{RST} pasta excluída da verificação do Defender" if r.returncode == 0
          else f"  {VERM}Falhou{RST} (execute como administrador)")


def ponto_restauracao():
    print("  Criando ponto de restauração (pode levar alguns segundos)...")
    r = rodar('powershell -NoProfile -Command "Checkpoint-Computer '
              "-Description 'TweaksMenu' -RestorePointType MODIFY_SETTINGS\"")
    if r.returncode == 0 and not r.stderr.strip():
        print(f"  {VERDE}OK{RST} ponto de restauração criado")
    else:
        print(f"  {AMA}Não foi possível criar.{RST} A Proteção do Sistema pode estar desligada,")
        print("  ou o Windows já criou um ponto nas últimas 24 horas.")


def reverter():
    backup = carregar_backup()
    if not backup:
        print("  Nada para reverter.")
        return
    for chave, antigo in backup.items():
        if chave == "_usb_suspend":
            sub_usb = "2a737441-1930-4402-8d77-b2bebba308a3"
            config = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
            rodar(f"powercfg /setacvalueindex {antigo} {sub_usb} {config} 1")
            rodar(f"powercfg /setdcvalueindex {antigo} {sub_usb} {config} 1")
            print(f"  {VERDE}OK{RST} suspensão seletiva de USB restaurada")
            continue
        if chave == "_plano_energia":
            rodar(f"powercfg -setactive {antigo}")
            print(f"  {VERDE}OK{RST} plano de energia restaurado")
            continue
        raiz, resto = chave.split("\\", 1)
        caminho, nome = resto.rsplit("\\", 1)
        try:
            if antigo is None:
                with winreg.OpenKey(ROOTS[raiz], caminho, 0, winreg.KEY_SET_VALUE) as k:
                    winreg.DeleteValue(k, nome)
            else:
                with winreg.CreateKeyEx(ROOTS[raiz], caminho, 0, winreg.KEY_SET_VALUE) as k:
                    winreg.SetValueEx(k, nome, 0, antigo["tipo"], antigo["valor"])
            print(f"  {VERDE}OK{RST} restaurado: {nome}")
        except Exception as e:
            print(f"  {VERM}Falhou{RST} {nome}: {e}")
    try:
        os.remove(ARQ_BACKUP)
    except OSError:
        pass
    print(f"  {AMA}Reinicie o PC para concluir.{RST}")


# ---------------------------------------------------------------- menu
PAGINAS = [
    ("Pagina 1 - Otimizações", [
        ("1", "Modo de Jogo ligado", modo_jogo),
        ("2", "Plano Alto Desempenho", plano_alto_desempenho),
        ("3", "Desativar Game DVR", desativar_game_dvr),
        ("4", "Efeitos visuais leves", efeitos_visuais),
        ("5", "GPU Scheduling (HAGS)", agendamento_gpu),
        ("6", "Diminuir Input Lag (mouse)", mouse_sem_aceleracao),
        ("7", "Desativar PresenceWriter", presence_writer),
        ("8", "Teclado: repeticao rapida", teclado_repeticao_rapida),
        ("9", "Desligar Teclas Aderentes/Filtro", desligar_teclas_aderentes_filtro),
        ("10", "USB sem suspensao seletiva", usb_sem_suspensao),
        ("11", "Aplicar tudo (1 a 10)", aplicar_tudo),
    ]),
    ("Pagina 2 - Ferramentas", [
        ("12", "MSConfig", abrir_msconfig),
        ("13", "AutoRuns (apps de inicializacao)", abrir_inicializacao),
        ("14", "Gerenciador de Tarefas", abrir_gerenciador),
        ("15", "Limpar arquivos temporarios", limpar_temp),
        ("16", "Criar ponto de restauracao", ponto_restauracao),
        ("17", "Reverter alteracoes", reverter),
        ("18", "Instalar MSI Afterburner", instalar_afterburner),
        ("19", "Excluir pasta de jogos do Defender", excluir_pasta_defender),
        ("20", "DESATIVAR seguranca do Windows", desativar_seguranca),
        ("21", "Reativar seguranca do Windows", reativar_seguranca),
    ]),
]


def desenhar(pagina):
    os.system("cls")
    print("\n" + banner() + "\n")
    print(MAG + "." * 78 + RST)
    titulo, itens = PAGINAS[pagina]
    for i in range(0, len(itens), 2):
        linha = ""
        for num, rotulo, _ in itens[i:i + 2]:
            linha += f"  {MAG}[{num}]{RST} {rotulo}".ljust(52)
        print(linha)
    print()
    outra = 2 if pagina == 0 else 1
    print(f"  {VERM}[X]{RST} {AMA}Pagina {outra}{RST}      {VERM}[0]{RST} {AMA}Sair{RST}")
    print(f"\n  {AMA}{titulo}{RST}")
    print(MAG + "." * 78 + RST)
    print(AZUL + "~by gustavo~".rjust(78) + RST)
    if not eh_admin():
        print(f"  {VERM}Aviso: não está como administrador. Algumas opções vão falhar.{RST}")


def elevar_se_necessario():
    """Se não estiver como administrador, reabre o programa pedindo permissão (UAC)."""
    if eh_admin():
        return
    if getattr(sys, "frozen", False):          # rodando como .exe
        exe = sys.executable
        params = " ".join(f'"{a}"' for a in sys.argv[1:])
    else:                                       # rodando como .py
        exe = sys.executable
        params = " ".join(f'"{a}"' for a in sys.argv)
    r = ctypes.windll.shell32.ShellExecuteW(None, "runas", exe, params, None, 1)
    if r > 32:
        sys.exit(0)                             # a nova janela (admin) assume
    print(f"{VERM}Permissão de administrador negada. O programa precisa dela para funcionar.{RST}")
    input("Pressione Enter para sair...")
    sys.exit(1)


def main():
    elevar_se_necessario()
    try:
        ctypes.windll.kernel32.SetConsoleTitleW("1155 by gustavo")
    except Exception:
        pass
    pagina = 0
    while True:
        desenhar(pagina)
        op = input("\n  Escolha: ").strip().lower()
        if op == "0":
            break
        if op == "x":
            pagina = 1 - pagina
            continue
        acao = next((f for p in PAGINAS for n, _, f in p[1] if n == op), None)
        if acao is None:
            continue
        print()
        acao()
        input("\n  Pressione Enter para voltar ao menu...")


if __name__ == "__main__":
    main()
