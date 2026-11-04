---
layout: default
title: "Entitat certificadora amb Active Directory"
description: "Missió Confiança — muntar una CA empresarial amb AD CS i donar HTTPS a una web interna amb un certificat oficial."
last_updated: 2026-11-04
---

# Entitat certificadora amb Active Directory

## <a id="index"></a>Índex

- [1. Resum](#1-resum)
  - [1.1 Conceptes](#11-conceptes)
  - [1.2 Què hi ha dins d'un certificat](#12-què-hi-ha-dins-dun-certificat)
  - [1.3 La cadena de confiança](#13-la-cadena-de-confiança)
  - [1.4 CA empresarial o CA independent](#14-ca-empresarial-o-ca-independent)
  - [1.5 Dues maneres de demanar un certificat](#15-dues-maneres-de-demanar-un-certificat)
  - [1.6 Eines](#16-eines)
- [2. La missió](#2-la-missió)
  - [Nivell 0 — La plataforma de llançament](#nivell-0--la-plataforma-de-llançament)
  - [Nivell 1 — Neix l'autoritat](#nivell-1--neix-lautoritat)
  - [Nivell 2 — La web del centre de control](#nivell-2--la-web-del-centre-de-control)
  - [Nivell 3 — El cadenat de pega](#nivell-3--el-cadenat-de-pega)
  - [Nivell 4 — El motlle](#nivell-4--el-motlle)
  - [Nivell 5 — La sol·licitud](#nivell-5--la-sollicitud)
  - [Nivell 6 — El cadenat oficial](#nivell-6--el-cadenat-oficial)
- [Feina (pràctica)](#feina-pràctica)

## 1. Resum

**La missió:** Òrbita Ebre és una empresa que acaba de posar en òrbita el seu primer satèl·lit, l'EBRE-1. El seu centre de control té una web interna que els navegadors marquen com "No segura". L'objectiu d'aquesta 1a part és crear l'entitat certificadora de l'empresa (**ORBITA-CA**) i donar-li a la web un certificat oficial i el cadenat.

### 1.1 Conceptes

| Concepte | Què és |
|---|---|
| Certificat digital | Un fitxer que diu «aquesta clau pública és d'aquest servidor o d'aquesta persona», signat per algú de confiança. És com un DNI, però digital. |
| Clau privada i clau pública | Una parella de claus que van juntes. El que es signa amb la privada només es pot comprovar amb la pública. La **privada** no surt mai de l'equip del propietari. La **pública** va dins del certificat i la pot veure tothom. |
| Entitat certificadora (CA) | Qui signa els certificats. Comprova qui ets i ho certifica amb la seva signatura, com fa la policia quan expedeix un DNI. |
| CA arrel | La CA de dalt de tot. El seu certificat se'l signa ella mateixa. Un equip confia en un certificat si, pujant per la cadena, arriba a una CA arrel que té a la seva llista de confiança. |
| PKI | Infraestructura de clau pública. El conjunt de CA, certificats, plantilles, llistes de revocació i normes per fer-los servir. |
| AD CS | *Servicios de certificados de Active Directory*. El rol de Windows Server que converteix el servidor en una CA. |
| Plantilla de certificat | El motlle d'un tipus de certificat. Diu per a què serveix, quant dura, d'on surt el nom i qui el pot demanar. |
| Sol·licitud (CSR) | El fitxer que s'envia a la CA per demanar un certificat. Porta el nom i la clau pública, mai la privada. |
| SAN | *Subject Alternative Name*, nom alternatiu del subjecte. La llista de noms per als quals és vàlid el certificat. Els navegadors actuals **només miren aquest camp** per comprovar el nom de la web. |
| Signatura digital | Un resum (*hash*) del contingut, xifrat amb la clau privada. Demostra qui ha signat i que el contingut no ha canviat des d'aleshores. |
| Revocació i CRL | Revocar és anul·lar un certificat abans que caduqui. La **CRL** és la llista negra signada que publica la CA amb els certificats revocats. |

### 1.2 Què hi ha dins d'un certificat

Exemple real (`control.orbita.cat`, certificat de servidor web):

| Camp | Valor | Equivalent a un DNI |
|---|---|---|
| Emès per a (*Subject*) | `CN=control.orbita.cat` | El nom i els cognoms |
| Noms vàlids (SAN) | `DNS=control.orbita.cat` | No en té. Una web pot tenir diversos noms |
| Emès per (*Issuer*) | `CN=ORBITA-CA` | Qui l'expedeix, la policia |
| Validesa | del 27/10/2026 al 27/10/2028 | La data de caducitat |
| Clau pública | RSA de 2048 bits | La foto, per comprovar que ets tu |
| Ús previst | Autenticació del servidor | Per a què serveix el document |
| Signatura | feta amb la clau privada d'ORBITA-CA | L'holograma, que no es pot falsificar |

> ⚠️ La **clau privada no és dins del certificat**. Es queda guardada a l'equip del propietari. El certificat és públic, i si algú te'l copia no passa res. Si algú et copia la clau privada, sí que hi ha un problema.

### 1.3 La cadena de confiança

```
ORBITA-CA (CA arrel, es signa ella mateixa)
   ├── signa → control.orbita.cat   (web del centre de control)
   └── signa → Lia Ferré             (carnet d'enginyera, 2a part)
```

El navegador o Windows pugen per la cadena. Si arriben a una CA arrel que tenen a la seva llista de confiança, confien en el certificat. Un "cadenat de pega" (un certificat que es signa ell mateix, sense cap CA) no convenç ningú — **ningú hi confia**.

### 1.4 CA empresarial o CA independent

| | CA empresarial | CA independent |
|---|---|---|
| Active Directory | La necessita. El servidor ha de ser del domini | No la necessita |
| Plantilles | Sí | No |
| Confiança dels equips | Automàtica. Els equips del domini la reben per AD | Cal instal·lar el certificat arrel a cada equip, a mà o per GPO |
| Emissió | Automàtica, segons els permisos de la plantilla | Les sol·licituds queden pendents fins que un administrador les aprova |
| On es fa servir | Dins d'una empresa amb domini | CA arrel fora de línia, o xarxes sense domini |

En aquesta pràctica es munta una **CA empresarial arrel**, al mateix servidor que el controlador de domini (en una empresa de veritat, la CA aniria en un servidor a part).

### 1.5 Dues maneres de demanar un certificat

Per al **servidor web**, la sol·licitud es fa a mà amb un fitxer `.inf` i l'ordre `certreq` (Nivell 5):

```
web.inf → certreq -new → web.req → certreq -submit → ORBITA-CA comprova i signa → web.cer → certreq -accept
```

Al pas 1 es crea la parella de claus. **La clau privada es queda al servidor i no viatja mai.** A la CA només hi arriba la clau pública, dins de la sol·licitud.

Per als **usuaris** (2a part), serà molt més fàcil: cada enginyer obrirà un assistent, marcarà la plantilla i prou.

### 1.6 Eines

| Eina | Per a què serveix |
|---|---|
| `certsrv.msc` | La consola de la CA. Certificats emesos i revocats, plantilles que emet, CRL |
| `certtmpl.msc` | Consola de plantilles. Duplicar-les i canviar-les |
| `certlm.msc` | Els certificats de l'equip (*local machine*) |
| `certreq -new · -submit · -accept` | Crea una sol·licitud · l'envia a la CA · instal·la el certificat rebut |
| `gpupdate /force` | Torna a aplicar les directives del domini ara mateix |
| `nslookup nom` | Pregunta al DNS quina IP té un nom |
| `Get-ChildItem Cert:\LocalMachine\My` | Llista els certificats personals de l'equip. `Root` en lloc de `My` mostra les CA arrel de confiança |
| `New-SelfSignedCertificate` | Fabrica un certificat signat per ell mateix |

## 2. La missió

Dues màquines virtuals a la mateixa Red NAT de VirtualBox:

| Peça | Valors |
|---|---|
| Xarxa | Red NAT `XarxaNAT`, `10.0.2.0/24`, porta d'enllaç `10.0.2.1` |
| Servidor | **DC-ORBITA** · IP fixa `10.0.2.6/24` · DNS preferit `127.0.0.1` · IPv6 desactivat |
| Domini | Bosc nou `orbita.cat`, nom NetBIOS `ORBITA` |
| Reenviadors DNS | `10.0.2.1` i `8.8.8.8` |
| Client | **PC-CONTROL** · IP fixa `10.0.2.20/24` · DNS `10.0.2.6` · unit a `orbita.cat` |

### Nivell 0 — La plataforma de llançament

Deixar a punt el domini `orbita.cat` amb el servidor i el client.

1. Crear la Red NAT `XarxaNAT` a VirtualBox i connectar-hi les dues màquines.
2. **SERVIDOR** Canviar el nom de l'equip a `DC-ORBITA` i reiniciar.
3. **SERVIDOR** Posar la IP fixa i el DNS `127.0.0.1`. Desactivar IPv6.
4. **SERVIDOR** Instal·lar el rol *Servicios de dominio de Active Directory* i promoure el servidor a controlador de domini d'un bosc nou, `orbita.cat`. Reiniciar.
5. **SERVIDOR** A Eines → DNS → propietats del servidor → pestanya Reenviadors, afegir `10.0.2.1` i `8.8.8.8`.
6. **CLIENT** Canviar el nom a `PC-CONTROL`, posar la IP fixa amb el DNS `10.0.2.6`, unir-lo al domini `orbita.cat` i reiniciar.
7. **CLIENT** Iniciar sessió com `ORBITA\Administrador`.

> **Per què el DNS del servidor és `127.0.0.1` i no `8.8.8.8`?** En un domini, el servidor i els equips han de trobar coses que només coneix el DNS del domini (`_ldap._tcp.dc._msdcs.orbita.cat`, `_kerberos._tcp...`, `dc-orbita.orbita.cat`...). Si es posa un DNS públic directament, es resolen noms d'Internet però fallen els serveis interns (Kerberos, GPO, AD CS). Per això el DNS del servidor apunta a ell mateix, i els **reenviadors** (`8.8.8.8`) són els que responen la resta.

**Comprovació** (CLIENT, PowerShell com `ORBITA\Administrador`):
```powershell
whoami
nslookup dc-orbita.orbita.cat
nslookup www.google.com
```

_Pendent — captures i resultats._

### Nivell 1 — Neix l'autoritat

Instal·lar AD CS i crear **ORBITA-CA**, una CA empresarial arrel.

**Part A · Instal·lar el rol** (SERVIDOR): Administrador del servidor → Administrar → Agregar roles y características → marcar *Servicios de certificados de Active Directory* → acceptar eines d'administració → Instalar.

**Part B · Configurar ORBITA-CA** (SERVIDOR): clicar *Configurar Servicios de certificados de Active Directory en el servidor de destino*, i omplir l'assistent:

| Pàgina | Valor |
|---|---|
| Credenciales | `ORBITA\Administrador` |
| Servicios de rol | Entidad de certificación |
| Tipo de instalación | CA empresarial |
| Tipo de CA | CA raíz |
| Clave privada | Crear una clau privada nova |
| Criptografía | RSA#Microsoft Software Key Storage Provider, 2048, SHA256 |
| Nombre de CA | `ORBITA-CA` |
| Período de validez | 5 Años |

**Part C · El client ja hi confia** (CLIENT): `gpupdate /force`, i comprovar amb:
```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like "*ORBITA*" | Format-List Subject, Issuer, NotAfter
```

> **Idea clau:** una CA empresarial es publica a Active Directory, i tots els equips del domini l'afegeixen a la seva llista de confiança automàticament. A partir d'ara, tot el que signi ORBITA-CA serà de confiança dins l'empresa.

_Pendent — captures i resultats._

### Nivell 2 — La web del centre de control

Crear el nom `control.orbita.cat` al DNS i publicar-hi la web amb IIS.

**Part A · El nom al DNS** (SERVIDOR): Eines → DNS → `DC-ORBITA` → Zonas de búsqueda directa → `orbita.cat` → botó dret → *Host nuevo (A o AAAA)* → nom `control`, IP `10.0.2.6`, sense PTR.

**Part B · El servidor web** (SERVIDOR): Agregar roles y características → *Servidor web (IIS)* → instal·lar. Crear la pàgina:
```powershell
New-Item C:\inetpub\wwwroot\index.html -ItemType File
notepad C:\inetpub\wwwroot\index.html
```

**Part C · Provar-ho** (CLIENT): Edge → `http://control.orbita.cat` → hauria de sortir la web, amb l'avís **"No seguro"**.

_Pendent — captures i resultats._

### Nivell 3 — El cadenat de pega

Posar HTTPS amb un certificat fet per un mateix, sense CA, i veure per què no serveix.

**Part A** (SERVIDOR):
```powershell
New-SelfSignedCertificate -DnsName control.orbita.cat -CertStoreLocation Cert:\LocalMachine\My -FriendlyName "Cadenat de pega"
```
Lligar-lo a IIS: Administrador de IIS → Default Web Site → Enlaces → Agregar → tipus `https`, port `443`, certificat SSL "Cadenat de pega".

**Part B** (CLIENT): finestra privada d'Edge → `https://control.orbita.cat` → avís de connexió no privada, codi **`NET::ERR_CERT_AUTHORITY_INVALID`**.

> **Idea clau:** el cadenat de pega xifra igual de bé que un d'oficial. El problema és que **qualsevol en pot fabricar un amb qualsevol nom**. Perquè te'n puguis fiar, l'ha de signar algú en qui confiïs.

_Pendent — captures i resultats._

### Nivell 4 — El motlle

Crear la plantilla **WebServer-SAN** a partir de la plantilla *Servidor web*, i publicar-la a ORBITA-CA.

**Part A · Duplicar la plantilla** (SERVIDOR, `certtmpl.msc`): botó dret sobre *Servidor web* → Plantilla duplicada.

| Pestanya | Configuració |
|---|---|
| Compatibilidad | Entidad de certificación: Windows Server 2016 · Destinatario: Windows 10/Windows Server 2016 |
| General | Nombre: `WebServer-SAN` · Período de validez: 2 Años |
| Nombre del sujeto | Proporcionado por el solicitante |
| Seguridad | `Equipos del dominio`: Leer + Inscribirse · `Admins. del dominio`: Leer + Escribir + Inscribirse |

**Part B · Publicar-la** (SERVIDOR, `certsrv.msc`): ORBITA-CA → Plantillas de certificado → Nuevo → Plantilla de certificado para emitir → `WebServer-SAN`.

> ⚠️ Crear la plantilla no n'hi ha prou — si no es publica a la CA, `certreq` fallarà amb `CERTSRV_E_UNSUPPORTED_CERT_TYPE`.

_Pendent — captures i resultats._

### Nivell 5 — La sol·licitud

Demanar el certificat de la web amb un fitxer `.inf` i `certreq`.

**Part A · La recepta** (SERVIDOR):
```powershell
mkdir C:\certs
cd C:\certs
New-Item web.inf -ItemType File
notepad web.inf
```

Contingut de `web.inf`:
```ini
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=control.orbita.cat"
FriendlyName = "Cadenat oficial"
KeyLength = 2048
KeySpec = 1
KeyUsage = 0xa0
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
RequestType = PKCS10
KeyAlgorithm = RSA

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=control.orbita.cat"

[RequestAttributes]
CertificateTemplate = WebServer-SAN
```

| Línia | Què vol dir |
|---|---|
| `Subject` | El nom del certificat |
| `FriendlyName` | El nom amistós, per distingir-lo del de pega a IIS |
| `KeyLength` / `KeyAlgorithm` | Una clau RSA de 2048 bits |
| `KeyUsage = 0xa0` | La clau servirà per signar (`0x80`) i per xifrar claus (`0x20`). És el que necessita HTTPS |
| `MachineKeySet = TRUE` | La clau es guarda a l'**equip**, no a l'usuari, perquè IIS la pugui fer servir |
| `2.5.29.17` | El número (OID) del camp **SAN**. A la línia de sota hi va el nom |
| `CertificateTemplate` | La plantilla que ha de fer servir ORBITA-CA. Ha de ser el nom exacte |

**Part B · Demanar, enviar i acceptar** (SERVIDOR):
```powershell
certreq -new web.inf web.req      # crea la sol·licitud (CSR) i la parella de claus
Get-Content web.req                # veure el contingut (PEM)
certreq -submit web.req web.cer    # l'envia a ORBITA-CA (triar-la a la finestra)
certreq -accept web.cer            # instal·la el certificat rebut
```

**Part C · Els dos cadenats, cara a cara** (SERVIDOR):
```powershell
Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -eq "CN=control.orbita.cat" | Format-List FriendlyName, Subject, Issuer, DnsNameList, NotAfter
```
Mateix nom i mateix SAN als dos certificats (pega i oficial). L'única diferència és l'**emissor**: el de pega se signa ell mateix, l'oficial l'ha signat ORBITA-CA.

> **Idea clau:** el certificat oficial no és millor per dins, i xifra igual. La diferència és **qui el signa**. I això ho canvia tot.

_Pendent — captures i resultats._

### Nivell 6 — El cadenat oficial

Canviar el certificat de pega pel certificat oficial a IIS.

**Part A · Canviar el certificat** (SERVIDOR): Administrador de IIS → Default Web Site → Enlaces → `https` → Modificar → Certificado SSL → **Cadenat oficial**.

**Part B · El cadenat** (CLIENT): finestra privada d'Edge → `https://control.orbita.cat`. La web surt a la primera, sense avís, amb el cadenat a l'esquerra de l'adreça. Al visor del certificat (pestanya Detalles) es veu la jerarquia: ORBITA-CA → `control.orbita.cat`.

> **Idea clau:** Edge mostra el cadenat perquè es compleixen quatre coses alhora: (1) el certificat l'ha signat ORBITA-CA, (2) ORBITA-CA és a la llista de confiança del client, (3) el nom de l'adreça surt al SAN, (4) el certificat no ha caducat ni està revocat. Si en falla una, surt l'avís.

> **I des de casa?** Un ordinador que no és del domini (com un portàtil personal) no té ORBITA-CA a la seva llista i veuria l'avís. Per això les webs d'Internet fan servir CA públiques (Let's Encrypt, DigiCert...), ja instal·lades als navegadors i sistemes operatius.

_Pendent — captures i resultats._

## Feina (pràctica)

> Pendent de fer — resum dels reptes de l'enunciat, sense resoldre encara.

- **Repte 0** (Nivell 0): captura dels reenviadors DNS i la zona `orbita.cat` amb el registre de `dc-orbita`.
- **Repte 1** (Nivell 1): comprovar a `certsrv.msc` que la ruta de certificació d'ORBITA-CA només té un nivell (és l'arrel).
- **Repte 2** (Nivell 2): obrir `http://10.0.2.6` i `http://dc-orbita.orbita.cat` en pestanyes noves — són tres noms per al mateix servidor.
- **Repte 3** (Nivell 3): fabricar un certificat fals per a `www.google.com` amb el nom amistós "Google de mentida", comprovar-lo i esborrar-lo.
- **Repte 4** (Nivell 4): a `certtmpl.msc`, mirar la pestanya Extensiones → Directivas de aplicación de `WebServer-SAN`.
- **Repte 5** (Nivell 5): a `certsrv.msc`, obrir el certificat emès i comprovar el nom DNS al detall.
- **Repte 6** (Nivell 6): obrir `https://10.0.2.6` i `https://dc-orbita.orbita.cat` en privat i veure per què ara sí que falla l'avís, encara que el certificat sigui oficial (relacionat amb el SAN).

**Lliurament de la 1a part:** captures 1 a 7 i reptes 1b a 7b. No esborrar res — cal fer una instantània de les dues màquines amb el nom "Web amb HTTPS" per a la 2a part (Carnets digitals per a l'equip).
