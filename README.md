# Linux Personal Tools

A personal collection of scripts, playbooks and utilities to diagnose,
mitigate and fix common Linux system issues — focused on security patching,
kernel vulnerabilities, and system administration automation.

---

## Philosophy

- **Automation first** — if you had to do it manually once, script it
- **Safe by default** — every tool includes a dry-run mode before making changes
- **Multi-distro** — tools target both Debian/Ubuntu and RHEL family where possible
- **Documented** — every tool includes its own README with context and usage

---

## Repository structure

```
Linux_Personal_Tools/
│
├── ansible-copyfail-CVE-2026-31431/   # CVE-2026-31431 (Copy Fail) remediation
│   ├── copyfail.yaml
│   ├── inventory.ini
│   └── README.md
│
└── ...                                # More tools coming
```

---

## Tools

| Tool | Type | Description | Distros |
|---|---|---|---|
| [ansible-copyfail-CVE-2026-31431](./ansible-copyfail-CVE-2026-31431) | Ansible Playbook | Detect, mitigate and patch CVE-2026-31431 (Copy Fail) — Linux kernel LPE via `algif_aead` | Ubuntu, RHEL, AlmaLinux, Debian |

---

## Requirements

Tools in this repo may require one or more of the following depending on the task:

- **Ansible 2.12+** — for playbooks
- **Python 3.10+** — on target hosts
- **sudo / become** — most tools require privilege escalation
- **SSH access** — for remote execution

---

## How to use

Each tool lives in its own subdirectory with a dedicated README explaining:
- What problem it solves
- What it changes on the system
- How to run it safely (dry-run first)
- Supported distributions

Always read the tool's README before running anything.

---

## Contributing

This is a personal repo but PRs and suggestions are welcome. If you spot a bug
or want to add support for a new distro, open an issue or submit a PR.

---

## Disclaimer

These tools are provided as-is for personal and educational use.
Always test in a non-production environment first.
The author is not responsible for any damage caused by misuse.
