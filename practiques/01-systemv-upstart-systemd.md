---
layout: default
title: "Sistemes d'inici"
---

# Sistemes d'inici

## <a id="index"></a>Índex

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
- [Feina (pràctica)](#feina-pràctica)

## 1. SystemV vs Upstart vs Systemd

**Conceptes bàsics**

- **Kernel** → gestiona els processos.
- **Aplicació** → programa interactiu, que s'executa amb l'usuari.
- **Servei** → programa associat al SO, que s'executa en 2n pla.
- **Procés** → funció interna del SO. Tant les aplicacions com els serveis, un cop en marxa, es converteixen en processos que el SO ha de gestionar i planificar.

**Els tres sistemes, en breu**

| | SystemV (SysV init) | Upstart | Systemd |
|---|---|---|---|
| Època | Init clàssic d'Unix, dècades d'ús a Linux | Ubuntu 2006–2015 (pas intermedi) | Estàndard actual a la majoria de distros |
| Model | Scripts seqüencials (`/etc/init.d`, `rcN.d`) | Basat en esdeveniments ("jobs"), mantenint compatibilitat amb `/etc/init.d` | Unitats declaratives (`.service`, `.target`...) amb dependències |
| Arrencada | Un servei rere l'altre, en ordre fix (`S##`) | Pot reaccionar a esdeveniments (ex: connectar un dispositiu), no només a un ordre fix | En paral·lel, seguint un graf de dependències |
| Estat avui | En desús (només compatibilitat) | Abandonat (substituït per systemd des d'Ubuntu 15.04) | Actiu — el que fem servir nosaltres |

Upstart va ser el pas intermedi d'Ubuntu entre SystemV i systemd: mantenia compatibilitat amb els scripts de `/etc/init.d` però afegia la capacitat d'arrencar/aturar serveis en resposta a esdeveniments. Ubuntu el va fer servir des de la versió 6.10 (2006) fins que el va substituir per systemd a partir de la 15.04 (2015).

### 1.1 Runlevels o targets?

**SystemV** parla de *runlevels* (nivells d'execució, numèrics). **Systemd** parla de *targets* (punts de sincronització amb nom). Són el mateix concepte amb dos noms diferents segons el sistema d'inici.

```bash
runlevel   # comanda clàssica de SystemV — a Ubuntu 26.04 no funciona (no hi ha compatibilitat instal·lada)
```

L'equivalent modern (systemd) és `systemctl get-default` (veure [3.2](#32-systemctl)).

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

Per esbrinar quin sistema d'inici fa servir realment la nostra màquina:

```bash
man init                    # documentació del binari /sbin/init
dpkg -S /sbin/init          # quin paquet ha instal·lat /sbin/init (ull: amb un sol guió "-S", no "–search")
readlink -f /sbin/init      # a on apunta realment /sbin/init (resol l'enllaç simbòlic sencer)
```

> ⚠️ A Ubuntu 26.04 `dpkg -S /sbin/init` pot no trobar-lo directament perquè `/sbin/init` és un enllaç simbòlic. Si falla, prova `dpkg -S $(readlink -f /sbin/init)`.

A qualsevol Ubuntu modern (com el nostre), `/sbin/init` apunta a `/lib/systemd/systemd` → el sistema d'inici real és **systemd**. Es manté `/sbin/init` només per compatibilitat amb eines/scripts antics que l'esperen.

## 2. SystemV

### 2.1 Directoris

```bash
cd /etc/init        # (Upstart, si n'hi ha restes — a distros modernes sol estar buit o no existir)
ls

cd /etc/init.d       # scripts d'arrencada/aturada clàssics de SystemV, un per servei
ls

cd /etc
ls | grep rc          # directoris rc0.d ... rc6.d, un per cada runlevel

cd /etc/rc0.d
ls
ls ../rc5.d
ls ../rc6.d
```

### 2.2 Procés d'arrencada

Dins de cada `/etc/rcN.d/` hi ha enllaços simbòlics (no còpies) cap als scripts de `/etc/init.d/`, amb un prefix que indica què fer i en quin ordre:

- **`S##nom`** → *Start*: engega el servei en entrar en aquest runlevel.
- **`K##nom`** → *Kill*: l'atura en sortir-ne.
- El número (`##`) marca l'ordre d'execució (més baix, abans).

```bash
/etc/init.d/cron restart   # executar directament el script (no fer "cd" amb arguments!)
# o bé:
service cron restart

init 6                      # canvia de runlevel → dispara els scripts K de l'actual i els S del 6 (reboot)
```

## 3. Systemd

**Per què systemd (i no SysV ni Upstart)?**

- **Arrencada en paral·lel**: SysV arrenca els serveis un darrere l'altre, seguint estrictament l'ordre numèric dels scripts `S##` de `/etc/rcN.d`. Systemd construeix un graf de dependències (`Requires=`, `After=`...) i arrenca en paral·lel tot allò que no depèn d'una altra cosa — per això el temps de boot és molt més curt.
- **Activació sota demanda (socket/D-Bus activation)**: un servei no cal que estigui ja engegat per rebre connexions — systemd pot "escoltar" el seu socket i arrencar el servei just quan arriba la primera petició, endarrerint (o evitant del tot) arrencades innecessàries.
- **Un sol format declaratiu**: en lloc d'un script de shell per servei (SysV/Upstart), una unitat `.service` descriu *què* fer i *de què depèn*, i és systemd qui decideix *quan* i *en quin ordre* executar-ho.

### 3.1 Directoris

Dos directoris importants (**no són el mateix camí, no es barregen**):

- **`/lib/systemd/system`** → unitats *per defecte*, instal·lades pels paquets. **Mai s'han de modificar aquí.**
- **`/etc/systemd/system`** → on van els canvis/overrides locals (per exemple, els enllaços que crea `systemctl enable`).

Tipus d'unitats més habituals: `.target`, `.service`, `.socket` (també existeixen `.mount`, `.timer`, `.path`, entre d'altres).

**Vols personalitzar un servei sense tocar `/lib`?**

```bash
systemctl edit ssh
```

Obre un editor i crea automàticament un fitxer *drop-in* a `/etc/systemd/system/ssh.service.d/override.conf`, on només cal escriure les línies que vulguis canviar (no cal copiar tot el `.service` sencer). Systemd combina l'original de `/lib` amb el teu override.

### 3.2 systemctl

```bash
systemctl list-units --type=target    # filtrar només els targets actius
systemctl list-units --type=service   # filtrar només els serveis actius

systemctl get-default                  # veure el target per defecte (equivalent modern de "runlevel")
ls -l /lib/systemd/system/runlevel*.target   # enllaços de compatibilitat runlevel → target
```

**Eines extra d'anàlisi:**

```bash
systemd-analyze         # temps total d'arrencada (firmware/kernel/userspace)
systemd-analyze blame   # quins serveis triguen més a arrencar
```

**Veure els logs d'un servei: `journalctl`**

```bash
journalctl -u ssh              # tots els logs del servei ssh
journalctl -u ssh -f           # en viu (com "tail -f")
journalctl -u ssh --since today
journalctl -p err              # només missatges d'error, de tots els serveis
```

És el complement natural de `systemctl status`: quan un servei no arrenca o falla, aquí és on es veu *per què*.

### 3.3 Dependències

```bash
ls -l /etc/systemd/system/graphical.target.wants/   # què s'engega amb aquest target
systemctl list-dependencies graphical.target         # arbre de dependències
```

### 3.4 Modificant target provisional

Canvi **temporal** (no sobreviu a un reinici):

```bash
systemctl isolate rescue.target
```

### 3.5 Modificant target definitiu

Canvi **permanent** del target per defecte. La manera segura i recomanada (no toca `/lib`, respecta la regla del punt 3.1):

```bash
systemctl set-default rescue.target
```

A classe també ho vam fer "a mà", movent l'enllaç `default.target`:

```bash
cd /lib/systemd/system
ls -l | grep target

rm default.target
ln -s rescue.target default.target
ls -l | grep target
```

> ⚠️ **Per confirmar:** aquest enllaç `default.target` normalment viu a `/etc/systemd/system/`, no a `/lib/systemd/system/` — i tocar `/lib` contradiu la regla del 3.1. Val la pena revisar a classe/VM en quin directori vam fer realment aquest canvi.

### 3.6 Afegir/treure serveis del target

```bash
apt install ssh

ls /etc/systemd/system/*.wants/ssh.service   # l'enllaç que demostra que el servei està "enganxat" a un target

systemctl enable ssh     # l'afegeix al target (crea l'enllaç a .wants/)
systemctl disable ssh    # el treu del target (elimina l'enllaç)
```

### 3.7 Creem un nou target

_Pendent — forma part de la [Feina](#feina-pràctica)._

### 3.8 Crear un nou servei

Exemple fet a classe: un servei que s'executa a l'arrencada, amb permisos de root, abans que arrenqui la resta del SO (a l'estil de l'antic `rc.local`).

**1. Creem l'script que ha d'executar el servei:**

```bash
cd /etc/
nano rc.local
```

```bash
#!/bin/sh -e

echo 'a' >> /etc/passwd
exit 0
```

```bash
chmod +x rc.local
```

**2. Creem la unitat de systemd que el crida:**

```bash
nano /etc/systemd/system/rc-local.service
```

```ini
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
```

**Què vol dir cada línia?**

| Directiva | Significat |
|---|---|
| `Description=` | Text descriptiu (surt a `systemctl status`) |
| `ConditionPathExists=` | Només s'executa si aquest fitxer existeix |
| `Type=forking` | El procés es "bifurca" i el pare original acaba (típic de dimonis clàssics) |
| `ExecStart=` | Comanda que engega el servei |
| `TimeoutSec=0` | Sense límit de temps per considerar-lo arrencat |
| `RemainAfterExit=yes` | Es considera "actiu" encara que el procés principal acabi |
| `WantedBy=multi-user.target` | A quin target s'"enganxa" en fer `systemctl enable` |

**3. L'activem i el comprovem:**

```bash
systemctl status rc-local.service
systemctl enable rc-local.service
systemctl restart rc-local.service
systemctl start rc-local.service
systemctl status rc-local.service

reboot
```

Després de reiniciar, `/etc/passwd` hauria d'haver-hi afegit la lletra `a` al final — prova que el servei s'ha executat amb permisos de root durant l'arrencada.

## Feina (pràctica)

> Pendent de fer — apunt de l'enunciat, sense resoldre encara.

- Crear un **target propi** (amb el nostre nom) a partir d'un dels targets existents (0–6), fent que en depengui (com si el "copiéssim").
- El nostre target ha de quedar com a **target per defecte** (`systemctl get-default` l'ha de mostrar) quan arrenqui la màquina.
- Dins d'aquest target, un **`.service` propi** que s'executi automàticament en iniciar-se el target (no fer servir `multi-user.target` per a això — ha de ser el nostre).
- Aquest servei ha d'executar un **script amb permisos de root, abans que acabi d'arrencar el SO** (seguint el patró de [3.8](#38-crear-un-nou-servei)).
- El script pot fer el que vulguem — alguna cosa "xula" per demostrar-ho (com l'exemple de la lletra `a` a `/etc/passwd`, però una mica més elaborat).

Captures i passos detallats: **pendents**.
