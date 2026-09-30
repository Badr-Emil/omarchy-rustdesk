# RustDesk for Omarchy

Bar widget that shows your [RustDesk](https://rustdesk.com) status and ID.

Click the icon to open the panel:

- **Your ID**: shown large, with a button to copy it
- **Connect to remote PC**: type a partner ID and press Enter (remote control) or use the folder button (file transfer). Typing digits anywhere in the panel jumps into the ID field
- **Recent**: your recent RustDesk sessions (from `~/.config/rustdesk/peers`), with remote control and file transfer buttons per row. Arrow keys / j k select, Enter connects
- **Install**: if RustDesk is missing, the panel offers to install `rustdesk-bin` from the AUR

Bar icon: right-click copies your ID, middle-click opens RustDesk. It turns red while someone is connected to this PC and is dimmed when RustDesk isn't running.

## Install

```bash
omarchy plugin add https://github.com/Badr-Emil/omarchy-rustdesk --enable
```

Requires `jq`, `wl-copy`, and `notify-send` (all shipped with Omarchy).

## Settings

- `refreshIntervalSec` (default 10): how often the status is polled
- `hideWhenIdle` (default false): only show the widget during a remote session

## Remove

```bash
omarchy plugin remove badr-emil.rustdesk
```
