# 1155

Menu de tweaks para Windows em Python, com interface de console colorida em duas páginas.
Por **Gustavo**.

*English: a small console menu of Windows gaming/performance tweaks, written in Python (stdlib only). Every registry change is backed up and can be reverted.*

> ⚠️ **Aviso:** o programa altera o registro, o plano de energia e (opcionalmente) a segurança do Windows.
> Use por sua conta e risco. Crie um ponto de restauração antes (opção 16) e leia o código antes de rodar.

## Recursos

**Página 1 – Otimizações**

| # | Opção |
|---|-------|
| 1 | Modo de Jogo ligado |
| 2 | Plano de energia Alto Desempenho |
| 3 | Desativar Game DVR |
| 4 | Efeitos visuais leves |
| 5 | Agendamento de GPU (HAGS) |
| 6 | Mouse sem aceleração (menos input lag) |
| 7 | Desativar PresenceWriter |
| 8 | Teclado: repetição rápida |
| 9 | Desligar Teclas Aderentes / Filtro |
| 10 | USB sem suspensão seletiva |
| 11 | Aplicar tudo (1 a 10) |

**Página 2 – Ferramentas**

| # | Opção |
|---|-------|
| 12–14 | Abrir MSConfig, apps de inicialização e Gerenciador de Tarefas |
| 15 | Limpar arquivos temporários |
| 16 | Criar ponto de restauração |
| 17 | **Reverter alterações** |
| 18 | Instalar MSI Afterburner (via winget) |
| 19 | Excluir uma pasta de jogos da verificação do Defender |
| 20 | **Desativar** segurança do Windows (Defender, Firewall, SmartScreen) – pede confirmação |
| 21 | Reativar segurança do Windows |

### Como funciona o "Reverter"

Antes de mudar qualquer valor do registro, o programa salva o valor original em
`%APPDATA%\TweaksMenu\backup.json`. A opção 17 restaura tudo a partir desse arquivo
(inclusive o plano de energia e a suspensão seletiva de USB).

## Download (sem instalar Python)

1. Abra a aba **[Releases](../../releases)** deste repositório.
2. Baixe o `1155.exe` da versão mais recente.
3. Dê dois cliques. O Windows pede permissão de administrador, é só aceitar.

> O Windows pode mostrar o aviso do SmartScreen ("Windows protegeu o computador"),
> porque o programa não tem assinatura digital paga. Clique em **Mais informações > Executar assim mesmo**.
> Se não confiar no executável, leia o código em `tweaks.py` e gere o seu próprio (veja abaixo).

## Requisitos

- Windows 10 ou 11
- Executar como administrador (o programa pede elevação via UAC sozinho)
- Python **só** se for rodar o código-fonte ou gerar o .exe você mesmo (3.8+, sem dependências externas)

## Rodar pelo código-fonte

```bat
python tweaks.py
```

## Gerar o .exe você mesmo

```bat
pip install pyinstaller
build.bat
```

O executável fica em `dist\1155.exe`.

### Publicação automática (para quem mantém o projeto)

O arquivo `.github/workflows/build.yml` gera o `1155.exe` no GitHub e o anexa ao Releases.
Para publicar uma versão, crie uma tag:

```bat
git tag v1.0.0
git push origin v1.0.0
```

Alguns minutos depois o `1155.exe` aparece em **Releases**.

> Executáveis do PyInstaller que pedem administrador e mexem no Defender podem gerar
> **falso positivo** em antivírus. Por isso o código-fonte é aberto e o .exe é gerado
> automaticamente pelo GitHub Actions, a partir deste mesmo código.

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md). Issues e pull requests são bem-vindos.

## Licença

[MIT](LICENSE) © 2026 Gustavo
