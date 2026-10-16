@echo off
rem Gera o 1155.exe (precisa de: pip install pyinstaller)
python -m PyInstaller --onefile --uac-admin --clean --name 1155 tweaks.py
echo.
echo Pronto: dist\1155.exe
pause
