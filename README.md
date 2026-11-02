### Report any issues in the [Issues](https://github.com/pdabrunst/Hermes-Tools/issues)

# Hermes-Tools

Utility scripts for [Hermes Agent](https://hermes-agent.nousresearch.com/).

## Contents

### Linux/hermes.sh

Terminal menu launcher for Hermes chat sessions.

- Browse existing chats with creation timestamps
- Start a new named chat
- Resume any previous session
- Delete one or more chats by number or range, e.g. `1 3-7 11`
- Auto-detects the Hermes database location
- One-time dependency installer with OS-aware package manager detection

## Usage

```bash
./Linux/hermes.sh
```

## Requirements

- `python3`
- `whiptail`
- `hermes`

The script will attempt to install missing dependencies automatically on first run.

## License

MIT — see [LICENSE](LICENSE).
