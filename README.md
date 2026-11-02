# Hermes-Tools

Utility scripts for [Hermes Agent](https://hermes-agent.nousresearch.com/).

Report any issues on the [Issues](https://github.com/pdabrunst/Hermes-Tools/issues) page.

## Contents

### Linux/Hermes-UI.sh

Terminal menu launcher for Hermes chat sessions.

- Browse existing chats with creation timestamps
- Start a new named chat
- Resume any previous session
- Delete one or more chats by number or range, e.g. `1 3-7 11`
- Auto-detects the Hermes database location
- One-time dependency installer with OS-aware package manager detection

#### Usage

```bash
./Linux/Hermes-UI.sh
```

#### Requirements

- `python3`
- `whiptail`
- `hermes`

The script will attempt to install missing dependencies automatically on first run.

---

### Windows/Hermes-UI.bat

One-file launcher for Hermes chat sessions on Windows.

- Same menu features as the Linux version
- Embedded PowerShell — no separate `.ps1` file needed
- Auto-detects `pwsh` or `powershell`
- Auto-detects the Hermes database location
- One-time dependency installer using `winget`, `choco`, or `scoop`

#### Usage

Double-click `Windows\Hermes-UI.bat` or run it from Command Prompt:

```cmd
Windows\Hermes-UI.bat
```

#### Requirements

- Python 3
- `hermes` CLI on PATH

If Python is missing, the launcher will attempt to install it using your available package manager.

#### Execution Policy

If PowerShell execution policy blocks scripts, the launcher bypasses it automatically for that session.

For a permanent fix, run PowerShell as Administrator and execute:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## License

MIT — see [LICENSE](LICENSE).
