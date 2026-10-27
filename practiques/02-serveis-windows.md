---
layout: default
title: "Serveis personalitzats a Windows"
description: "Crear un servei de Windows que executi un script amb NSSM, i desactivar un servei innecessari."
last_updated: 2026-10-27
---

# Serveis personalitzats a Windows

## <a id="index"></a>Índex

- [1. Per què NSSM?](#1-per-què-nssm)
- [2. Preparació](#2-preparació)
- [3. L'script](#3-lscript)
- [4. Registrar el servei](#4-registrar-el-servei)
- [5. Comprovar-ho](#5-comprovar-ho)
- [6. Desactivar un servei innecessari](#6-desactivar-un-servei-innecessari)
- [Comparativa amb systemd](#comparativa-amb-systemd)
- [Feina (pràctica)](#feina-pràctica)

## 1. Per què NSSM?

Windows no té una manera senzilla de "convertir" un script en servei real, tal com fa systemd amb un simple fitxer `.service`. **NSSM** (*Non-Sucking Service Manager*) és una eina que fa d'embolcall: registra qualsevol programa (en el nostre cas, `powershell.exe` executant un script) com si fos un servei normal de Windows, visible a `services.msc`.

## 2. Preparació

Descarrega NSSM des de [nssm.cc](https://nssm.cc/) i descomprimeix-lo (per exemple a `C:\nssm-2.24\`).

> ⚠️ **Important:** tots els passos s'han de fer amb **PowerShell com a Administrador** (clic dret → "Executar com a administrador"), no amb `cmd`. `cmd` no té prou permisos per registrar serveis al sistema.

## 3. L'script

Un script que deixa constància que el servei s'ha engegat, i que es manté viu escrivint una línia nova cada minut (això permet comprovar, més tard, que el servei segueix actiu i no s'ha aturat sol):

```powershell
# C:\Scripts\meu-servei.ps1
$logPath = "C:\ProgramData\MeuServei\log.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null

Add-Content -Path $logPath -Value "Servei iniciat: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"

while ($true) {
    Add-Content -Path $logPath -Value "Servei actiu: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Start-Sleep -Seconds 60
}
```

**Per què un bucle `while($true)`?** A diferència d'un `Type=oneshot` de systemd (que s'executa i acaba), NSSM espera per defecte un procés que es quedi **en marxa**— si el script acaba, NSSM entén que el servei ha "caigut" i el torna a engegar. El bucle és el que fa que Windows el vegi com a *Running* de manera contínua.

## 4. Registrar el servei

```powershell
$nssm        = "C:\nssm-2.24\win64\nssm.exe"
$serviceName = "MeuServei"
$powershell  = (Get-Command powershell).Source
$scriptPath  = "C:\Scripts\meu-servei.ps1"
$arguments   = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath

& $nssm install $serviceName $powershell $arguments
```

**Què fa cada variable?**

| Variable | Significat |
|---|---|
| `$nssm` | Camí a l'executable `nssm.exe` |
| `$serviceName` | Nom amb què es registrarà el servei a Windows |
| `$powershell` | Camí real de `powershell.exe` al sistema |
| `$scriptPath` | Camí al nostre script `.ps1` |
| `$arguments` | Paràmetres que es passen a PowerShell en engegar el servei |

`-ExecutionPolicy Bypass` salta el bloqueig per defecte que Windows aplica a l'execució de scripts `.ps1`, **només per aquesta execució concreta** (no canvia cap configuració global del sistema).

> **Captura 1:** finestra o sortida de `nssm install` confirmant "Service ... installed successfully!".

## 5. Comprovar-ho

```powershell
Start-Service MeuServei
Get-Service MeuServei
Get-Content C:\ProgramData\MeuServei\log.txt -Tail 5
```

> **Captura 2:** `Get-Service` mostrant l'estat `Running`, i el contingut del `log.txt` amb diverses línies.

> **Captura 3:** el servei visible a `services.msc`, amb el *Startup Type* en **Automatic** (per confirmar que arrencarà sol la propera vegada).

Reinicia l'ordinador i torna a comprovar el `log.txt`: hauria d'haver-hi una línia nova de "Servei iniciat" sense que hagis fet res manualment.

> **Captura 4:** `log.txt` després d'un reinici, mostrant que el servei s'ha tornat a engegar sol.

## 6. Desactivar un servei innecessari

Segona part de l'exercici: identificar un servei que no calgui i desactivar-lo per no consumir recursos.

```powershell
Get-Service | Where-Object {$_.Status -eq "Running"}   # per veure quins estan actius
Set-Service -Name "NomDelServei" -StartupType Disabled
Stop-Service -Name "NomDelServei"
```

> **Captura 5:** el servei triat abans (en *Running*) i després (*Stopped*, *Disabled*), amb una frase explicant per què has triat aquell en concret.

## Comparativa amb systemd

Taula de referència per connectar-ho amb el que ja vam veure a la pràctica de [Sistemes d'inici](01-systemv-upstart-systemd.html):

| Concepte | systemd (Linux) | NSSM (Windows) |
|---|---|---|
| Registrar el servei | fitxer `.service` + `daemon-reload` | `nssm install` |
| Arrencada automàtica | `WantedBy=` + `systemctl enable` | *Startup type: Automatic* |
| Veure l'estat | `systemctl status` | `Get-Service` / `services.msc` |
| Desactivar | `systemctl disable` | `Set-Service -StartupType Disabled` |
| Logs | `journalctl -u servei` | fitxer de log propi (Windows no té un equivalent directe tan senzill) |

## Feina (pràctica)

> Pendent de fer — resum de l'enunciat.

- Crear un servei de Windows amb NSSM que executi un script en el mode d'inici de sessió habitual.
- Comprovar que el servei s'inicia correctament (també després d'un reinici).
- Desactivar un servei existent que no calgui, per estalviar recursos.

Captures: **pendents** (veure els punts marcats més amunt).
