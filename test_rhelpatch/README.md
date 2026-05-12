# CVE-2026-31431 (Copy Fail) — Ansible Remediation Playbook

Playbook de Ansible para detectar, mitigar y parchear servidores Linux vulnerables a
**Copy Fail** (CVE-2026-31431), una vulnerabilidad de escalada de privilegios locales
en el subsistema criptográfico del kernel Linux.

---

## ¿Qué es Copy Fail?

| Campo | Detalle |
|---|---|
| CVE | CVE-2026-31431 |
| Nombre | Copy Fail |
| CVSS | 7.8 (High) |
| Divulgado | 2026-04-29 |
| Descubridor | Xint Code (Theori) |
| Componente afectado | `algif_aead` — módulo del kernel Linux (AF_ALG crypto API) |
| Impacto | Escalada de privilegios a root por cualquier usuario local sin privilegios |
| Exploit público | Sí — script Python de 732 bytes, sin recompilación, funciona en todas las distros |

### Distribuciones afectadas

Todo kernel Linux compilado desde 2017 hasta que se aplique el parche, incluyendo:

- Ubuntu 14.04 → 25.10 (24.04 Noble es vulnerable; **26.04 Resolute NO está afectada**)
- RHEL / AlmaLinux / Rocky Linux / CentOS
- Debian
- Amazon Linux 2023
- SUSE 16
- Fedora, Arch Linux

### Fix upstream

Commit [`a664bf3d603d`](https://git.kernel.org/linus/a664bf3d603dc3bdcf9ae47cc21e0daec706d7a5)
en kernel 7.0-rc7 — revierte la optimización in-place introducida en 2017.

---

## Estructura del repositorio

```
.
├── copyfail.yaml       # Playbook principal
├── inventory.ini       # Inventario de hosts (editar antes de correr)
└── README.md
```

---

## Requisitos

- Ansible 2.12+
- Python 3.10+ en los hosts objetivo
- Acceso sudo en los hosts objetivo
- Conectividad SSH a los hosts (o `ansible_connection=local` para localhost)

Verificar instalación:
```bash
ansible --version
```

---

## Inventario

Edita `inventory.ini` según tu entorno:

```ini
# Prueba local
[local]
localhost ansible_connection=local

# Servidores remotos
[webservers]
web01 ansible_host=192.168.1.10 ansible_user=ubuntu
web02 ansible_host=192.168.1.11 ansible_user=ubuntu

[dbservers]
db01 ansible_host=192.168.1.20 ansible_user=ec2-user
```

---

## Módulos del playbook

El playbook está dividido en 7 bloques que se ejecutan en orden:

### Bloque 1 — Detección automática
Evalúa cada host antes de tocar nada:
- Versión del kernel activo (`uname -r`)
- Si `algif_aead` está cargado en `/proc/modules`
- Si hay procesos usando `AF_ALG` activamente (`lsof`)
- Versión de `kmod` instalada vs. versión segura (Ubuntu)
- Si la mitigación ya estaba aplicada previamente
- Excepciones seguras: Ubuntu 14.04/16.04 con kernel 3.13 o 4.4 (no afectados)
- Hosts Ubuntu 26.04+ son marcados automáticamente como `NO_AFECTADO` y saltados

### Bloque 2 — Mitigación temporal (Debian/Ubuntu)
Deshabilita `algif_aead` via `modprobe.d`:
```
/etc/modprobe.d/disable-algif-aead.conf → install algif_aead /bin/false
```
Si el módulo está en uso activo (detectado por `lsof`), no lo descarga a la fuerza
y avisa que se aplicará en el próximo reinicio.

### Bloque 3 — Mitigación temporal (RHEL family)
En RHEL/AlmaLinux/Rocky, `algif_aead` está compilado dentro del kernel
(`CONFIG_CRYPTO_USER_API_AEAD=y`), por lo que `modprobe.d` **no funciona**.
Se usa `grubby` para agregar `initcall_blacklist=algif_aead_init` al bootloader:
```bash
grubby --update-kernel=ALL --args="initcall_blacklist=algif_aead_init"
```

### Bloque 4 — Actualización del kernel
Remediación definitiva vía gestor de paquetes:
- **Debian/Ubuntu**: `apt` — actualiza `linux-image-generic` y `kmod`
- **RHEL/AlmaLinux**: `dnf` — actualiza `kernel*`

Se puede omitir con `mitigation_only=true`.

### Bloque 5 — Reinicio
Reinicia el servidor para activar el nuevo kernel.
Configurable con `reboot_after_patch=false` para diferirlo.

### Bloque 6 — Verificación post-parche
Confirma el estado final:
- Versión del kernel activo tras reinicio
- Si `algif_aead` sigue o no en memoria
- Versión de `kmod` instalada (Ubuntu)
- Estado final: `REMEDIADO` o `VERIFICAR`

### Bloque 7 — Reporte CSV
Genera un CSV en el nodo de control con todos los hosts procesados:
- Hosts parchados → `REMEDIADO` o `VERIFICAR`
- Hosts no afectados → `NO_AFECTADO`

Archivo generado en: `/tmp/copyfail_report_<epoch>.csv`

```
hostname,os,kernel_version,estado,kmod_version,timestamp
web01,Ubuntu 22.04,5.15.0-133-generic,REMEDIADO,29-1ubuntu1.1,2026-05-11T14:32:01Z
bastion,Ubuntu 26.04,6.11.0-26-generic,NO_AFECTADO,N/A,2026-05-11T14:32:05Z
db01,AlmaLinux 9.6,5.14.0-570.62.1.el9_6,REMEDIADO,N/A,2026-05-11T14:32:06Z
```

---

## Variables principales

| Variable | Default | Descripción |
|---|---|---|
| `reboot_after_patch` | `true` | Reiniciar tras aplicar el parche |
| `mitigation_only` | `false` | Solo mitiga, no actualiza el kernel |

---

## Cómo correr el playbook

### 1. Dry-run (sin cambios reales)
Siempre recomendado como primer paso:
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  --check --diff \
  -e "reboot_after_patch=false" \
  -e "mitigation_only=true" \
  --ask-become-pass
```

### 2. Solo mitigación (sin reinicio ni actualización de kernel)
Útil para servidores críticos que no puedes bajar ahora:
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  -e "reboot_after_patch=false" \
  -e "mitigation_only=true" \
  --ask-become-pass
```

### 3. Remediación completa con reinicio
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  --ask-become-pass
```

### 4. Remediación completa sin reinicio inmediato
```bash
ansible-playbook -i inventory.ini copyfail.yaml \
  -e "reboot_after_patch=false" \
  --ask-become-pass
```

### 5. Ver el reporte CSV generado
```bash
cat /tmp/copyfail_report_*.csv
```

---

## Notas importantes

- La mitigación via `modprobe.d` **no funciona en RHEL family** — el módulo está
  compilado en el kernel. El playbook detecta esto automáticamente y usa `grubby`.
- La mitigación **no afecta** dm-crypt/LUKS, kTLS, IPsec, SSH, OpenSSL ni GnuTLS.
  Solo impacta aplicaciones que usen AF_ALG directamente para AEAD (muy raro).
- El exploit es determinista, no requiere condiciones de carrera y funciona igual
  en todas las arquitecturas. Priorizar Kubernetes nodes y CI/CD runners.
- Ubuntu 26.04 (Resolute) y kernels posteriores **no están afectados**.

---

## Referencias

- [copy.fail](https://copy.fail) — Advisory oficial del investigador
- [Xint Code write-up](https://xint.io/blog/copy-fail-linux-distributions)
- [Ubuntu Security Advisory USN-8226-1](https://ubuntu.com/security/notices/USN-8226-1)
- [CERT-EU Advisory 2026-005](https://cert.europa.eu/publications/security-advisories/2026-005/)
- [Microsoft Security Blog](https://www.microsoft.com/en-us/security/blog/2026/05/01/cve-2026-31431-copy-fail-vulnerability-enables-linux-root-privilege-escalation/)
- [Tenable FAQ](https://www.tenable.com/blog/copy-fail-cve-2026-31431-frequently-asked-questions-about-linux-kernel-privilege-escalation)
- [NVD — CVE-2026-31431](https://nvd.nist.gov/vuln/detail/CVE-2026-31431)
