---
layout: default
title: "Sistemes d'inici"
description: "SystemV vs Upstart vs Systemd: runlevels, targets, directoris, systemctl i gestió de serveis."
last_updated: 2026-09-23
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

Un target no és res "màgic": és un fitxer `.target` que actua com a **etiqueta de sincronització** — diu "quan jo estigui actiu, aquestes altres unitats també ho han d'estar". Crear un target propi vol dir crear un fitxer nou que **hereta** tot el que ja fa un target existent, i després hi enganxem el nostre servei.

**1. Creem el fitxer del target** (sempre a `/etc/systemd/system/`, mai a `/lib`, com al punt 3.1):

```bash
nano /etc/systemd/system/aso.target
```

```ini
[Unit]
Description=Target personalitzat ASO
Requires=multi-user.target
After=multi-user.target
AllowIsolate=yes
```

**Què vol dir cada línia?**

| Directiva | Significat |
|---|---|
| `Requires=multi-user.target` | El nostre target **necessita** que `multi-user.target` estigui actiu — en activar-se el nostre, arrossega tot el que ja porta aquell (xarxa, serveis bàsics...). És el "que en depengui" de l'enunciat. |
| `After=multi-user.target` | Garanteix l'**ordre**: primer s'activa `multi-user.target` sencer, i només després el nostre. |
| `AllowIsolate=yes` | Imprescindible: per defecte un target nou no es pot activar amb `systemctl isolate` ni fer-se target per defecte — cal permetre-ho explícitament. |

> **Captura 1:** contingut del fitxer `/etc/systemd/system/aso.target` (`cat /etc/systemd/system/aso.target`).

**2. Que systemd se n'assabenti:**

```bash
systemctl daemon-reload
```

systemd llegeix els fitxers `.service`/`.target` un cop i els guarda en memòria. Si n'afegim o modifiquem un a mà, systemd no se n'entera fins que li diem explícitament que torni a llegir-los.

**3. El provem (target provisional — punt 3.4):**

```bash
systemctl isolate aso.target
```

> **Captura 2:** sortida de `systemctl get-default` (encara mostrant l'antic) i `systemctl list-units --type=target` just després de l'`isolate`, per demostrar que `aso.target` ja està actiu encara que no sigui el per defecte.

**4. El fem definitiu (punt 3.5):**

```bash
systemctl set-default aso.target
```

> **Captura 3:** `systemctl get-default` mostrant ara `aso.target`.

**5. Hi enganxem el nostre servei** (connecta amb el punt 3.6): al fitxer `.service` que fem servir (veure [3.8](#38-crear-un-nou-servei)), a `[Install]` posem:

```ini
WantedBy=aso.target
```

En lloc de `multi-user.target`. Amb `systemctl enable elteuservei.service`, systemd crea l'enllaç a `/etc/systemd/system/aso.target.wants/` — exactament el mateix mecanisme que vam veure amb `ssh.service` i `multi-user.target.wants/` al punt 3.6.

> **Captura 4:** `ls -l /etc/systemd/system/aso.target.wants/` mostrant l'enllaç al nostre servei.

**Resum del flux:**

```
aso.target (nou, hereta de multi-user.target)
    └── aso.target.wants/
          └── elteuservei.service → executa el teu script com a root
```

> **Captura 5:** després d'un `reboot`, sortida de `systemctl status aso.target` i `systemctl status elteuservei.service` (o `journalctl -u elteuservei`) demostrant que tot s'ha activat automàticament a l'arrencada.

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

**Enunciat:**

- Crear un **target propi** (amb el nostre nom) a partir d'un dels targets existents (0–6), fent que en depengui (com si el "copiéssim").
- El nostre target ha de quedar com a **target per defecte** (`systemctl get-default` l'ha de mostrar) quan arrenqui la màquina.
- Dins d'aquest target, un **`.service` propi** que s'executi automàticament en iniciar-se el target (no fer servir `multi-user.target` per a això — ha de ser el nostre).
- Aquest servei ha d'executar un **script amb permisos de root, abans que acabi d'arrencar el SO** (seguint el patró de [3.8](#38-crear-un-nou-servei)).
- El script pot fer el que vulguem — alguna cosa "xula" per demostrar-ho (com l'exemple de la lletra `a` a `/etc/passwd`, però una mica més elaborat).

El target (`aso.target`) ja està fet al punt [3.7](#37-creem-un-nou-target). El que faltava era l'`.service` i l'script reals. Aquí sota hi ha la solució completa.

### L'script: comptador d'arrencades + banner a `/etc/motd`

En lloc de només afegir una lletra a `/etc/passwd`, l'script fa tres coses cada cop que arrenca la màquina, totes amb permisos de root:

1. Porta un **comptador d'arrencades** persistent a `/var/lib/aso/boot-count` (demostra, arrencada rere arrencada, que el servei s'executa sempre).
2. Deixa constància a `/var/log/aso-boot.log` (data, número d'arrencada, target actiu, host, IP, kernel).
3. Genera un **banner** a `/etc/motd` amb tota aquesta informació — el primer que es veu en fer login (SSH o consola) després d'arrencar.

[`aso-boot.sh`]({{ '/practiques/scripts/aso-boot.sh' | relative_url }}):

```bash
#!/bin/bash
set -e

LOGFILE="/var/log/aso-boot.log"
COUNTFILE="/var/lib/aso/boot-count"
MOTDFILE="/etc/motd"

mkdir -p "$(dirname "$COUNTFILE")"

if [ -f "$COUNTFILE" ]; then
    COUNT=$(($(cat "$COUNTFILE") + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTFILE"

HOST=$(hostname)
KERNEL=$(uname -r)
DATA=$(date '+%Y-%m-%d %H:%M:%S')
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
TARGET=$(systemctl get-default)
PUJADA=$(uptime -p)

echo "[$DATA] Arrencada #$COUNT - target=$TARGET - host=$HOST - ip=${IP:-cap} - kernel=$KERNEL" >> "$LOGFILE"

cat > "$MOTDFILE" <<EOF

╔══════════════════════════════════════════════╗
  ASO · $HOST
  Target actiu:    $TARGET
  Arrencada núm.:  $COUNT
  Data:            $DATA
  Kernel:          $KERNEL
  IP:              ${IP:-(sense xarxa)}
  Uptime:          $PUJADA
╚══════════════════════════════════════════════╝

EOF

exit 0
```

```bash
sudo cp aso-boot.sh /usr/local/bin/aso-boot.sh
sudo chmod +x /usr/local/bin/aso-boot.sh
```

### El servei: `aso.service`

```bash
sudo nano /etc/systemd/system/aso.service
```

```ini
[Unit]
Description=Servei personalitzat ASO - banner d'arrencada
After=aso.target
Requires=aso.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/aso-boot.sh
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=aso.target
```

**Diferències respecte al `rc-local.service` del [3.8](#38-crear-un-nou-servei):**

| Directiva | Per què canvia |
|---|---|
| `Type=oneshot` (en lloc de `forking`) | El nostre script no es bifurca ni queda resident: s'executa d'un tir i acaba. `oneshot` és el tipus pensat per a això. |
| `RemainAfterExit=yes` | Igual que al 3.8: encara que el procés acabi de seguida, systemd el considera "actiu" (surt com a `active (exited)` a `systemctl status`). |
| `WantedBy=aso.target` (en lloc de `multi-user.target`) | És el punt clau de l'enunciat: el servei s'enganxa al **nostre** target, no al genèric. |
| `After=` / `Requires=aso.target` | Assegura que el servei només arrenca quan `aso.target` (i, per herència, `multi-user.target`) ja estan actius. |

### Activar-ho tot

```bash
sudo systemctl daemon-reload
sudo systemctl enable aso.service      # crea l'enllaç a /etc/systemd/system/aso.target.wants/
sudo systemctl start aso.service       # el prova sense esperar a un reboot
systemctl status aso.service
cat /etc/motd
```

> **Captura 1:** `cat /usr/local/bin/aso-boot.sh` i `cat /etc/systemd/system/aso.service`.

> **Captura 2:** `systemctl status aso.target` i `systemctl status aso.service` just després del `start` manual, mostrant `active (exited)`.

### Prova real: reiniciar diverses vegades

La prova de foc és que el comptador pugi sol, sense intervenció, arrencada rere arrencada:

```bash
sudo reboot
# ... un cop tornada a arrencar la màquina:
systemctl get-default            # ha de mostrar aso.target
cat /etc/motd                    # banner actualitzat, comptador +1
cat /var/log/aso-boot.log        # una línia nova per cada arrencada
journalctl -u aso.service -b     # logs del servei en aquest darrer boot
```

> **Captura 3:** `systemctl get-default` mostrant `aso.target` com a target per defecte.

> **Captura 4:** `cat /etc/motd` després d'almenys dues arrencades seguides, mostrant el comptador incrementant-se.

> **Captura 5:** `cat /var/log/aso-boot.log` amb diverses línies (una per arrencada) i `journalctl -u aso.service -b` confirmant que el servei s'ha executat correctament al darrer boot.
