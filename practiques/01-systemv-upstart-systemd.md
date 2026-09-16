# Sistemes d'inici

## Índex

- [1. SystemV vs Upstart vs Systemd](#1-systemv-vs-upstart-vs-systemd)
  - [1.1 Runlevels o targets?](#11-runlevels-o-targets)
  - [1.2 Quin és el nostre SO?](#12-quin-és-el-nostre-so)
- [2. SystemV](#2-systemv)
  - [2.1 Directoris](#21-directoris)
  - [2.2 Procés d'arrencada](#22-procés-darrencada)
- [3. Systemd](#3-systemd)
  - [3.1 Directoris](#31-directoris)
  - [3.2 systemctl](#32-systemctl)
  - [3.3 Dependències](#33-dependències)
  - [3.4 Modificant target provisional](#34-modificant-target-provisional)
  - [3.5 Modificant target definitiu](#35-modificant-target-definitiu)
  - [3.6 Afegir/treure serveis del target](#36-afegirtreure-serveis-del-target)
  - [3.7 Creem un nou target](#37-creem-un-nou-target)
  - [3.8 Crear un nou servei](#38-crear-un-nou-servei)

## 1. SystemV vs Upstart vs Systemd

**Conceptes bàsics**

- **Kernel** → gestiona els processos.
- **Aplicació** → programa interactiu, que s'executa amb l'usuari.
- **Servei** → programa associat al SO, que s'executa en 2n pla.
- **Procés** → funció interna del SO. Tant les aplicacions com els serveis, un cop en marxa, es converteixen en processos que el SO ha de gestionar i planificar.

### 1.1 Runlevels o targets?

**Nivells d'execució (runlevels)**

| Nivell | Significat |
|---|---|
| 0 | Power off (apagat) |
| 1 | Rescue / mode d'un sol usuari |
| 2–5 | Multiusuari, xarxa, entorn gràfic... (varia segons la distribució) |
| 6 | Reboot |

**Tres formes equivalents d'aturar un servei**, segons el sistema d'inici:

```bash
/etc/init.d/cron stop     # SystemV clàssic (script directe)
service cron stop         # comanda "service" (compatibilitat/Upstart)
systemctl stop cron       # Systemd
```

### 1.2 Quin és el nostre SO?

## 2. SystemV

### 2.1 Directoris

### 2.2 Procés d'arrencada

## 3. Systemd

### 3.1 Directoris

### 3.2 systemctl

### 3.3 Dependències

### 3.4 Modificant target provisional

### 3.5 Modificant target definitiu

### 3.6 Afegir/treure serveis del target

### 3.7 Creem un nou target

### 3.8 Crear un nou servei
