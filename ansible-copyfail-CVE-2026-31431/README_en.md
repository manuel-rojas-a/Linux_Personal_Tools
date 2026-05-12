# CVE-2026-31431 (Copy Fail) — Ansible Remediation Playbook

Ansible playbook to detect, mitigate and patch Linux servers vulnerable to
**Copy Fail** (CVE-2026-31431), a local privilege escalation vulnerability
in the Linux kernel's cryptographic subsystem.

---

## What is Copy Fail?

| Field | Detail |
|---|---|
| CVE | CVE-2026-31431 |
| Name | Copy Fail |
| CVSS | 7.8 (High) |
| Disclosed | 2026-04-29 |
| Discoverer | Xint Code (Theori) |
| Affected component | `algif_aead` — Linux kernel module (AF_ALG crypto API) |
| Impact | Privilege escalation to root by any unprivileged local user |
| Public exploit | Yes — 732-byte Python script, no recompilation, works across all distros |

### Affected distributions

Every Linux kernel compiled since 2017 until the patch is applied, including:

- Ubuntu 14.04 → 25.10 (24.04 Noble is vulnerable; **26.04 Resolute is NOT affected**)
- RHEL / AlmaLinux / Rocky Linux / CentOS
- Debian
- Amazon Linux 2023
- SUSE 16
- Fedora, Arch Linux

### Upstream fix

Commit [`a664bf3d603d`](https://git.kernel.org/linus/a664bf3d603dc3bdcf9ae47cc21e0daec706d7a5)
in kernel 7.0-rc7 — reverts the in-place optimization introduced in 2017.

---

## Repository structure

```
.
├── copyfail.yaml       # Main playbook
├── inventory.ini       # Host inventory (edit before running)
└── README.md
```

---

## Requirements

- Ansible 2.12+
- Python 3.10+ on target hosts
- sudo access on target hosts
- SSH connectivity to hosts (or `ansible_connection=local` for localhost)

Verify installation:
```bash
ansible --version
```

---

## Inventory

Edit `inventory.ini` according to your environment:

```ini
# Local test
[local]
localhost ansible_connection=local

# Remote servers
[webservers]
web01 ansible_host=192.168.1.10 ansible_user=ubuntu
web02 ansible_host=192.168.1.11 ansible_user=ubuntu

[dbservers]
db01 ansible_host=192.168.1.20 ansible_user=ec2-user
```

---

## Playbook modules

The playbook is divided into 7 blocks that run in order:

### Block 1 — Automatic detection
Evaluates each host before making any changes:
- Active kernel version (`uname -r`)
- Whether `algif_aead` is loaded in `/proc/modules`
- Whether any process is actively using `AF_ALG` (`lsof`)
- Installed `kmod` version vs. safe version (Ubuntu)
- Whether mitigation was already applied previously
- Safe exceptions: Ubuntu 14.04/16.04 with kernel 3.13 or 4.4 (not affected)
- Ubuntu 26.04+ hosts are automatically marked `NOT_AFFECTED` and skipped

### Block 2 — Temporary mitigation (Debian/Ubuntu)
Disables `algif_aead` via `modprobe.d`:
```
/etc/modprobe.d/disable-algif-aead.conf → install algif_aead /bin/false
```
If the module is actively in use (detected by `lsof`), it will not be forcefully
unloaded — a warning is shown and the mitigation will apply on next reboot.

### Block 3 — Temporary mitigation (RHEL family)
On RHEL/AlmaLinux/Rocky, `algif_aead` is compiled directly into the kernel
(`CONFIG_CRYPTO_USER_API_AEAD=y`), so `modprobe.d` **does not work**.
`grubby` is used to add `initcall_blacklist=algif_aead_init` to the bootloader:
```bash
grubby --update-kernel=ALL --args="initcall_blacklist=algif_aead_init"
```

### Block 4 — Kernel update
Definitive remediation via package manager:
- **Debian/Ubuntu**: `apt` — updates `linux-image-generic` and `kmod`
- **RHEL/AlmaLinux**: `dnf` — updates `kernel*`

Can be skipped with `mitigation_only=true`.

### Block 5 — Reboot
Reboots the server to activate the new kernel.
Can be deferred with `reboot_after_patch=false`.

### Block 6 — Post-patch verification
Confirms the final state:
- Active kernel version after reboot
- Whether `algif_aead` is still in memory
- Installed `kmod` version (Ubuntu)
- Final status: `PATCHED` or `VERIFY`

### Block 7 — CSV report
Generates a CSV on the control node with all processed hosts:
- Patched hosts → `PATCHED` or `VERIFY`
- Unaffected hosts → `NOT_AFFECTED`

File generated at: `/tmp/copyfail_report_<epoch>.csv`

```
hostname,os,kernel_version,status,kmod_version,timestamp
web01,Ubuntu 22.04,5.15.0-133-generic,PATCHED,29-1ubuntu1.1,2026-05-11T14:32:01Z
bastion,Ubuntu 26.04,6.11.0-26-generic,NOT_AFFECTED,N/A,2026-05-11T14:32:05Z
db01,AlmaLinux 9.6,5.14.0-570.62.1.el9_6,PATCHED,N/A,2026-05-11T14:32:06Z
```

---

## Main variables

| Variable | Default | Description |
|---|---|---|
| `reboot_after_patch` | `true` | Reboot after applying the patch |
| `mitigation_only` | `false` | Only mitigate, do not update the kernel |

---

## How to run the playbook

### 1. Dry-run (no real changes)
Always recommended as a first step:
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  --check --diff \
  -e "reboot_after_patch=false" \
  -e "mitigation_only=true" \
  --ask-become-pass
```

### 2. Mitigation only (no reboot, no kernel update)
Useful for critical servers that cannot be taken down right now:
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  -e "reboot_after_patch=false" \
  -e "mitigation_only=true" \
  --ask-become-pass
```

### 3. Full remediation with reboot
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  --ask-become-pass
```

### 4. Full remediation without immediate reboot
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  -e "reboot_after_patch=false" \
  --ask-become-pass
```

### 5. View the generated CSV report
```bash
cat /tmp/copyfail_report_*.csv
```

---

## Important notes

- The `modprobe.d` mitigation **does not work on RHEL family** — the module is
  compiled into the kernel. The playbook detects this automatically and uses `grubby`.
- The mitigation **does not affect** dm-crypt/LUKS, kTLS, IPsec, SSH, OpenSSL or GnuTLS.
  Only impacts applications that use AF_ALG directly for AEAD (very rare in practice).
- The exploit is deterministic, requires no race conditions and works identically
  across all architectures. Prioritize Kubernetes nodes and CI/CD runners.
- Ubuntu 26.04 (Resolute) and later kernels are **not affected**.

---

## References

- [copy.fail](https://copy.fail) — Researcher's official advisory
- [Xint Code write-up](https://xint.io/blog/copy-fail-linux-distributions)
- [Ubuntu Security Advisory USN-8226-1](https://ubuntu.com/security/notices/USN-8226-1)
- [CERT-EU Advisory 2026-005](https://cert.europa.eu/publications/security-advisories/2026-005/)
- [Microsoft Security Blog](https://www.microsoft.com/en-us/security/blog/2026/05/01/cve-2026-31431-copy-fail-vulnerability-enables-linux-root-privilege-escalation/)
- [Tenable FAQ](https://www.tenable.com/blog/copy-fail-cve-2026-31431-frequently-asked-questions-about-linux-kernel-privilege-escalation)
- [NVD — CVE-2026-31431](https://nvd.nist.gov/vuln/detail/CVE-2026-31431)
