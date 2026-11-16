---
layout: default
title: "Entitat certificadora amb Active Directory"
description: "Muntar una CA empresarial arrel (ORBITA-CA) amb AD CS i donar HTTPS amb cadenat oficial a una web interna. Certificats, plantilles SAN, CSR i cadena de confiança."
last_updated: 2026-11-16
---

# Entitat certificadora amb Active Directory

> **Missió Confiança · 1a part · La web amb HTTPS · Windows Server**
>
> Òrbita Ebre és una empresa petita que governa el seu satèl·lit (l'EBRE-1) des d'un centre de control amb una web interna. Cada cop que algú obre la web, el navegador diu **No segur**: tot viatja en clar i ningú pot assegurar que la web és de veritat. En aquesta pràctica muntem l'entitat certificadora de l'empresa, **ORBITA-CA**, i amb ella donem a la web un certificat oficial i el cadenat.

## <a id="index"></a>Índex

- [1. Conceptes (teoria)](#1-conceptes-teoria)
  - [1.1 Què és un certificat digital](#11-què-és-un-certificat-digital)
  - [1.2 Què hi ha dins d'un certificat](#12-què-hi-ha-dins-dun-certificat)
  - [1.3 La cadena de confiança](#13-la-cadena-de-confiança)
  - [1.4 CA empresarial o CA independent](#14-ca-empresarial-o-ca-independent)
  - [1.5 Dues maneres de demanar un certificat](#15-dues-maneres-de-demanar-un-certificat)
  - [1.6 Eines](#16-eines)
- [2. L'escenari](#2-lescenari)
- [Nivell 0 — La plataforma de llançament](#nivell-0--la-plataforma-de-llançament)
- [Nivell 1 — Neix l'autoritat](#nivell-1--neix-lautoritat)
- [Nivell 2 — La web del centre de control](#nivell-2--la-web-del-centre-de-control)
- [Nivell 3 — El cadenat de pega](#nivell-3--el-cadenat-de-pega)
- [Nivell 4 — El motlle](#nivell-4--el-motlle)
- [Nivell 5 — La sol·licitud](#nivell-5--la-sol·licitud)
- [Nivell 6 — El cadenat oficial](#nivell-6--el-cadenat-oficial)
- [Captures a lliurar](#captures-a-lliurar)

---

## 1. Conceptes (teoria)

### 1.1 Què és un certificat digital

Un **certificat digital** és un fitxer que diu «aquesta clau pública és d'aquest servidor o d'aquesta persona», signat per algú de confiança. És com un DNI, però digital: una autoritat en qui tothom confia certifica que aquesta identitat és real.

| Concepte | Què és |
|---|---|
| **Certificat digital** | Fitxer que lliga una identitat (un nom) amb una clau pública, signat per una CA. Com un DNI digital. |
| **Clau privada i clau pública** | Una parella de claus que van juntes. El que es signa amb la privada només es pot comprovar amb la pública. La **privada** no surt mai de l'equip del propietari. La **pública** va dins del certificat i la pot veure tothom. |
| **Entitat certificadora (CA)** | Qui signa els certificats. Comprova qui ets i ho certifica amb la seva signatura, com fa la policia quan expedeix un DNI. |
| **CA arrel** | La CA de dalt de tot. El seu certificat se'l signa ella mateixa. Un equip confia en un certificat si, pujant per la cadena, arriba a una CA arrel que té a la seva llista de confiança. |
| **PKI** | *Public Key Infrastructure*. El conjunt de CA, certificats, plantilles, llistes de revocació i normes per fer-los servir. |
| **AD CS** | *Servicios de certificados de Active Directory*. El rol de Windows Server que converteix el servidor en una CA. |
| **Plantilla de certificat** | El motlle d'un tipus de certificat. Diu per a què serveix, quant dura, d'on surt el nom i qui el pot demanar. |
| **Sol·licitud (CSR)** | El fitxer que s'envia a la CA per demanar un certificat. Porta el nom i la clau pública, mai la privada. |
| **SAN** | *Subject Alternative Name*. La llista de noms per als quals és vàlid el certificat. Els navegadors actuals **només miren aquest camp** per comprovar el nom de la web. |
| **Signatura digital** | Un resum (*hash*) del contingut, xifrat amb la clau privada. Demostra qui ha signat i que el contingut no ha canviat des d'aleshores. |
| **Revocació i CRL** | Revocar és anul·lar un certificat abans que caduqui. La **CRL** és la llista negra signada que publica la CA amb els certificats revocats. |

### 1.2 Què hi ha dins d'un certificat

Aquest és el certificat que tindrà la web del centre de control quan acabem el nivell 6. Al costat, a què s'assembla cada camp en un DNI:

| Camp | Valor | Al DNI seria |
|---|---|---|
| Emès per a (*Subject*) | `CN=control.orbita.cat` | El nom i els cognoms |
| Noms vàlids (SAN) | `DNS=control.orbita.cat` | No en té. Una web pot tenir diversos noms |
| Emès per (*Issuer*) | `CN=ORBITA-CA` | Qui l'expedeix, la policia |
| Validesa | del 27/10/2026 al 27/10/2028 | La data de caducitat |
| Clau pública | RSA de 2048 bits | La foto, per comprovar que ets tu |
| Ús previst | Autenticación del servidor | Per a què serveix el document |
| Signatura | feta amb la clau privada d'ORBITA-CA | L'hologram, que no es pot falsificar |

> ⚠️ La **clau privada no és dins del certificat**. Es queda guardada a l'equip del propietari. El certificat és públic, i si algú te'l copia no passa res. Si algú et copia la clau privada, sí que hi ha un problema.

### 1.3 La cadena de confiança

```
                     ORBITA-CA  (CA arrel, es signa ella mateixa)
                     · a la llista de confiança de tots els equips del domini
                      /                               \
                  signa                             signa
                    ↓                                   ↓
        control.orbita.cat                           Lia Ferré
        web del centre de control              carnet d'enginyera (2a part)
        plantilla WebServer-SAN                plantilla SignaturaScripts
```

El navegador o Windows pugen per la cadena. Si arriben a una CA arrel de la seva llista, confien en el certificat. Un **cadenat de pega** (certificat autofirmat, nivell 3) es signa ell mateix i ningú hi confia; un **cadenat oficial** (nivell 6) l'ha signat ORBITA-CA, que sí que és a la llista de confiança.

### 1.4 CA empresarial o CA independent

En aquesta pràctica muntem una **CA empresarial arrel**, al mateix servidor que el controlador de domini (en una empresa de veritat, la CA aniria en un servidor a part).

| | CA empresarial | CA independent |
|---|---|---|
| Active Directory | La necessita. El servidor ha de ser del domini | No la necessita |
| Plantilles | Sí | No |
| Confiança dels equips | Automàtica. Els equips del domini la reben per AD | Cal instal·lar el certificat arrel a cada equip, a mà o per GPO |
| Emissió | Automàtica, segons els permisos de la plantilla | Les sol·licituds queden pendents fins que un administrador les aprova |
| On es fa servir | Dins d'una empresa amb domini | CA arrel fora de línia, o xarxes sense domini |

L'avantatge clau de l'empresarial: quan publiquem ORBITA-CA, **tots els equips del domini l'afegeixen sols a la seva llista de confiança**. No cal anar equip per equip.

### 1.5 Dues maneres de demanar un certificat

Per al **servidor web** farem la sol·licitud a mà amb un fitxer `.inf` i l'ordre `certreq` (nivell 5). Així es veu cada peça del procés:

```
web.inf    →    web.req    →    ORBITA-CA    →    web.cer    →    Magatzem
(la recepta)   (la sol·licitud,  (comprova       (el certificat)   (de l'equip,
               CSR)              i signa)                           amb la clau privada)

  certreq -new        certreq -submit      ORBITA-CA el retorna     certreq -accept
```

Al pas 1 es crea la parella de claus. **La clau privada es queda al servidor i no viatja mai.** A la CA només hi arriba la clau pública, dins de la sol·licitud.

Per als **usuaris** (2a part de la missió) serà molt més fàcil: cada enginyer obrirà un assistent, marcarà la plantilla i prou. El nom del certificat el posarà Active Directory i la clau privada es crearà al seu equip.

### 1.6 Eines

| Eina | Per a què serveix |
|---|---|
| `certsrv.msc` | La consola de la CA. Certificats emesos i revocats, plantilles que emet, CRL |
| `certtmpl.msc` | Consola de plantilles. Duplicar-les i canviar-les |
| `certlm.msc` | Els certificats de l'**equip** (*local machine*) |
| `certreq -new · -submit · -accept` | Crea una sol·licitud · l'envia a la CA · instal·la el certificat rebut |
| `gpupdate /force` | Torna a aplicar les directives del domini ara mateix |
| `nslookup nom` | Pregunta al DNS quina IP té un nom |
| `Get-ChildItem Cert:\LocalMachine\My` | Llista els certificats personals de l'equip. `\Root` mostra les CA arrel de confiança |
| `New-SelfSignedCertificate` | Fabrica un certificat signat per ell mateix |

> Les consoles s'obren amb <kbd>Win</kbd>+<kbd>R</kbd> i el nom de la consola.

---

## 2. L'escenari

Dues màquines virtuals a la mateixa **Red NAT** de VirtualBox (`XarxaNAT`, `10.0.2.0/24`, porta d'enllaç `10.0.2.1`):

| Peça | Valors |
|---|---|
| **DC-ORBITA** (SERVIDOR) | Windows Server · IP fixa `10.0.2.6/24` · DNS preferit `127.0.0.1` · IPv6 desactivat · rol AD DS + DNS + AD CS + IIS · domini `orbita.cat` (bosc nou, NetBIOS `ORBITA`) |
| **PC-CONTROL** (CLIENT) | Windows 10/11 Pro · IP fixa `10.0.2.20/24` · DNS `10.0.2.6` · unit al domini `orbita.cat` |

> Cada pas porta una etiqueta de color: **SERVIDOR** (DC-ORBITA) o **CLIENT** (PC-CONTROL). Si es fa un pas a la màquina equivocada, no funciona. Fes una instantània de cada màquina abans de començar.

---

## Nivell 0 — La plataforma de llançament

> Deixem a punt el domini `orbita.cat` amb el servidor i el client. El domini ja el sabem muntar de pràctiques anteriors, per això aquí només en tenim el resum. Abans de llançar res cal una base sòlida: amb un domini mal configurat, l'entitat certificadora falla de maneres molt estranyes.

**Què s'ha de fer:**

1. Crear la Red NAT `XarxaNAT` a VirtualBox i connectar-hi les dues màquines.
2. **SERVIDOR** · Canviar el nom de l'equip a `DC-ORBITA` i reiniciar.
3. **SERVIDOR** · Posar la IP fixa `10.0.2.6/24`, porta d'enllaç `10.0.2.1`, DNS preferit `127.0.0.1`. Desactivar IPv6 desmarcant *Protocolo de Internet versión 6 (TCP/IPv6)* a les propietats de l'adaptador.
4. **SERVIDOR** · Instal·lar el rol *Servicios de dominio de Active Directory* i promoure el servidor a controlador de domini d'un **bosc nou**, `orbita.cat`. Reiniciar.
5. **SERVIDOR** · A *Herramientas › DNS*, obre les propietats del servidor i, a la pestanya *Reenviadores*, afegeix `10.0.2.1` i `8.8.8.8`.
6. **CLIENT** · Canviar el nom a `PC-CONTROL`, posar la IP fixa amb DNS `10.0.2.6`, unir-lo al domini `orbita.cat` i reiniciar.
7. **CLIENT** · Iniciar sessió com `ORBITA\Administrador`.

> ⚠️ **Per què el DNS del servidor és `127.0.0.1` i no `8.8.8.8`.** En un domini, el servidor i els equips han de trobar coses que **només coneix el DNS del domini**: registres SRV com `_ldap._tcp.dc._msdcs.orbita.cat` i `_kerberos._tcp.orbita.cat`, i noms interns com `dc-orbita.orbita.cat` i `control.orbita.cat`. Si poses un DNS públic a la targeta de xarxa, resoldràs `google.com` però no els serveis del domini: IIS demana credencials perquè falla Kerberos, les GPO fan coses rares i els equips no troben el controlador. El lloc del `8.8.8.8` són els **reenviadors**: el teu DNS respon el que és del domini i pregunta a fora tota la resta.

**Comprovació** · CLIENT · PowerShell:

```powershell
whoami
nslookup dc-orbita.orbita.cat
nslookup www.google.com
```

Les dues `nslookup` han de donar adreça. `UnKnown` com a nom del servidor és normal (no hi ha zona de cerca inversa, i en aquesta pràctica no la necessitem).

> **Captura 1:** al client, la sortida de `whoami` i dels dos `nslookup`.

![Captura 1 — whoami i nslookup al client]({{ '/assets/practiques/03-entitat-certificadora-ad/captura1.png' | relative_url }})

> **Repte 0 (captura 1b):** al servidor, obre l'*Administrador de DNS* i fes una captura on es vegin els reenviadors i la zona `orbita.cat` amb el registre de `dc-orbita`. Després fes la instantània de les dues màquines.

---

## Nivell 1 — Neix l'autoritat

> Instal·lem AD CS i creem ORBITA-CA, una CA empresarial arrel. Després veurem que el client hi confia sense que fem res. Tota l'operació depèn d'aquesta peça: ORBITA-CA serà la «policia» que expedeix els DNI digitals de l'empresa.

**SERVIDOR · Part A · Instal·lar el rol**

1. Obre l'*Administrador del servidor* i ves a *Administrar › Agregar roles y características*. Prem *Siguiente* fins a *Roles de servidor*.
2. Marca *Servicios de certificados de Active Directory*. S'obre una finestra que vol afegir les eines d'administració: prem *Agregar características*.
3. Prem *Siguiente* fins a *Servicios de rol*. Deixa marcat només *Entidad de certificación*.
4. Prem *Siguiente* i *Instalar*. Quan acabi, **no tanquis la finestra**.

**SERVIDOR · Part B · Configurar ORBITA-CA**

5. A la mateixa finestra, fes clic a l'enllaç *Configurar Servicios de certificados de Active Directory en el servidor de destino* (si l'has tancada, el mateix enllaç surt a la banderola groga de dalt de l'Administrador del servidor).
6. Omple l'assistent pàgina per pàgina amb aquests valors, i a cada pàgina prem *Siguiente*:

   | Pàgina | Què hi has de posar |
   |---|---|
   | Credenciales | `ORBITA\Administrador` (cal un administrador d'empresa) |
   | Servicios de rol | Marca *Entidad de certificación* |
   | Tipo de instalación | *CA empresarial* |
   | Tipo de CA | *CA raíz* |
   | Clave privada | *Crear una clave privada nueva* |
   | Criptografía | Deixa-ho com està: `RSA#Microsoft Software Key Storage Provider`, 2048, SHA256 |
   | Nombre de CA | `ORBITA-CA` (a sota veuràs el sufix `DC=orbita,DC=cat`) |
   | Período de validez | `5` *Años* |
   | Base de datos de certificados | Deixa les carpetes que surten |
   | Confirmación | Revisa-ho i prem *Configurar* |

7. Quan l'assistent digui que la configuració ha acabat bé, prem *Cerrar*.
8. Obre la consola de la CA: <kbd>Win</kbd>+<kbd>R</kbd> → `certsrv.msc`. A l'esquerra surt ORBITA-CA amb un senyal verd. A dins hi ha *Certificados revocados*, *Certificados emitidos*, *Solicitudes pendientes*, *Solicitudes erróneas* i *Plantillas de certificado*.

**CLIENT · Part C · El client ja hi confia**

9. Al client, obre PowerShell i força l'actualització de les directives del domini:

   ```powershell
   gpupdate /force
   ```

10. <kbd>Win</kbd>+<kbd>R</kbd> → `certlm.msc` → *Entidades de certificación raíz de confianza › Certificados*. Entre els certificats de Microsoft i d'altres empreses, ara hi ha **ORBITA-CA**. Ningú l'ha instal·lat a mà: ha arribat sol des d'Active Directory.

11. Comprova-ho també des de PowerShell:

    ```powershell
    Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like "*ORBITA*" | Format-List Subject, Issuer, NotAfter
    ```

    El subjecte i l'emissor són el mateix (`CN=ORBITA-CA, DC=orbita, DC=cat`): ORBITA-CA s'ha signat ella mateixa, perquè és l'arrel. Caduca d'aquí a 5 anys.

> 💡 Una CA empresarial es publica a Active Directory, i tots els equips del domini l'afegeixen a la seva llista de confiança. A partir d'ara, **tot el que signi ORBITA-CA serà de confiança dins de l'empresa**.

> ⚠️ Si ORBITA-CA no surt al client, reinicia'l i torna-ho a mirar. Si encara no hi és, revisa que el client tingui el DNS `10.0.2.6`.

> **Captura 2:** la consola `certsrv.msc` del servidor amb ORBITA-CA, i el `certlm.msc` del client amb ORBITA-CA dins de les entitats arrel de confiança.

![Captura 2 — certsrv.msc al servidor amb ORBITA-CA]({{ '/assets/practiques/03-entitat-certificadora-ad/captura2-servidor.png' | relative_url }})

Al client, la confiança en ORBITA-CA es comprova des de PowerShell (arriba sola per AD, amb la mateixa empremta digital que al servidor):

![Captura 2 — ORBITA-CA a les arrels de confiança del client]({{ '/assets/practiques/03-entitat-certificadora-ad/captura2-client.png' | relative_url }})

> **Repte 1 (captura 2b):** a `certsrv.msc`, clic dret sobre ORBITA-CA › *Propiedades* › *Ver certificado* › pestanya *Ruta de certificación*. Fes una captura on es vegi que la ruta només té un nivell. És el senyal que ORBITA-CA és l'arrel.

> 💡 Un cop fet amb l'assistent, tot això es pot repetir des de PowerShell amb dues ordres:
> ```powershell
> Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
> Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -CACommonName "ORBITA-CA" -ValidityPeriod Years -ValidityPeriodUnits 5
> ```

---

## Nivell 2 — La web del centre de control

> Creem el nom `control.orbita.cat` al DNS i hi publiquem la web del centre de control amb IIS. De moment, funciona sense cadenat.

**SERVIDOR · Part A · El nom al DNS**

1. A l'*Administrador del servidor*, obre *Herramientas › DNS*.
2. A l'esquerra, obre `DC-ORBITA › Zonas de búsqueda directa › orbita.cat`.
3. Clic dret sobre `orbita.cat` i tria *Host nuevo (A o AAAA)…*.
4. Omple la finestra:
   - **Nombre** `control` (a sota veuràs el nom complet, `control.orbita.cat`).
   - **Dirección IP** `10.0.2.6` (la del servidor, que també farà de servidor web).
   - **No marquis** *Crear registro del puntero (PTR) asociado*.

   Prem *Agregar host*, *Aceptar* i *Listo*.
5. Comprova el nom nou des de PowerShell com a administrador:

   ```powershell
   nslookup control.orbita.cat
   ```

   Ha de respondre `control.orbita.cat → 10.0.2.6`. Si no respon, buida la memòria cau del DNS amb `ipconfig /flushdns` i torna-ho a provar.

**SERVIDOR · Part B · El servidor web**

6. Torna a *Administrar › Agregar roles y características*. A *Roles de servidor*, marca *Servidor web (IIS)* i prem *Agregar características*. Prem *Siguiente* fins a *Instalar*, espera que acabi i prem *Cerrar*.
7. Al PowerShell d'administrador, crea la pàgina nova i obre-la amb el Bloc de notes:

   ```powershell
   New-Item C:\inetpub\wwwroot\index.html -ItemType File
   notepad C:\inetpub\wwwroot\index.html
   ```

8. Escriu-hi la web del centre de control i desa-la amb <kbd>Ctrl</kbd>+<kbd>S</kbd>:

   ```html
   <!DOCTYPE html>
   <html lang="ca">
   <head>
   <meta charset="utf-8">
   <title>Centre de control EBRE-1</title>
   </head>
   <body style="background:#0b1530; color:#ffffff; font-family:Segoe UI, sans-serif; text-align:center; padding-top:60px">
   <h1>Centre de control EBRE-1</h1>
   <p>Òrbita Ebre · Telemetria del satèl·lit</p>
   <p style="font-size:40px">550 km · TOT CORRECTE</p>
   <p>Accés només per a personal autoritzat</p>
   </body>
   </html>
   ```

   IIS busca `index.html` abans que `iisstart.htm`, així que ara sortirà la nostra.

**CLIENT · Part C · Provar-ho**

9. Al client, obre Microsoft Edge i ves a `http://control.orbita.cat`. Surt el centre de control. A l'esquerra de l'adreça, Edge diu **No seguro**: tot el que viatja va en clar.

> **Captura 3:** Edge al client amb la web del centre de control i l'avís *No seguro*.

![Captura 3 — web HTTP amb avís No seguro]({{ '/assets/practiques/03-entitat-certificadora-ad/captura3.png' | relative_url }})

> **Repte 2 (captura 3b):** obre en pestanyes noves `http://10.0.2.6` i `http://dc-orbita.orbita.cat`. Surt la mateixa web? Fes una captura on es vegin les tres pestanyes. Són tres noms per al mateix servidor; recorda-ho, que al nivell 6 tornarà a sortir.

---

## Nivell 3 — El cadenat de pega

> Posem HTTPS a la web amb un certificat fet per nosaltres mateixos, sense cap CA, i veiem per què no serveix. Un enginyer impacient diu que ell ho arregla en un minut: fabrica un certificat ell mateix i el posa a la web.

**SERVIDOR · Part A · Fabricar el certificat i posar-lo a IIS**

1. Al PowerShell d'administrador, fabrica un certificat autofirmat per a `control.orbita.cat`:

   ```powershell
   New-SelfSignedCertificate -DnsName control.orbita.cat -CertStoreLocation Cert:\LocalMachine\My -FriendlyName "Cadenat de pega"
   ```

   El certificat té el nom correcte, però no l'ha signat cap CA: l'ha signat ell mateix. El nom amistós, `FriendlyName`, servirà per reconèixer-lo a IIS.
2. Obre *Herramientas › Administrador de Internet Information Services (IIS)*. A l'esquerra, obre `DC-ORBITA › Sitios › Default Web Site`.
3. A la dreta, a *Acciones*, prem *Enlaces…* › *Agregar…*.
4. Omple l'enllaç nou:
   - **Tipo** `https`
   - **Dirección IP** *Todas las no asignadas* · **Puerto** `443` · **Nombre de host** buit
   - **Certificado SSL** *Cadenat de pega*

   Prem *Aceptar* i *Cerrar*. Ara la web escolta pel port 80 (`http`) i pel 443 (`https`).

**CLIENT · Part B · Què en pensa el navegador**

5. Al client, obre una finestra privada d'Edge (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd>) i ves a `https://control.orbita.cat`. Edge no mostra la web: surt una pàgina d'avís que diu que la connexió no és privada.
6. Prem el botó d'opcions avançades. El codi és:

   ```
   NET::ERR_CERT_AUTHORITY_INVALID
   ```

   Vol dir que el certificat l'ha signat una autoritat en què Edge no confia. En aquest cas, el certificat mateix.
7. **No** continuïs cap a la web. Tanca la finestra privada.

> 💡 El cadenat de pega xifra igual de bé que un d'oficial. El problema és que **qualsevol en pot fabricar un amb qualsevol nom**. És com un DNI fet a casa amb la impressora: perquè te'n puguis fiar, l'ha de signar algú en qui confiïs.

> ⚠️ Si una web de veritat et mostra aquest avís, no continuïs. Pot ser un atacant que es fa passar per la web.

> **Captura 4:** la pàgina d'avís d'Edge amb el codi `NET::ERR_CERT_AUTHORITY_INVALID`.

![Captura 4 — avís NET::ERR_CERT_AUTHORITY_INVALID]({{ '/assets/practiques/03-entitat-certificadora-ad/captura4.png' | relative_url }})

> **Repte 3 (captura 4b):** al servidor, fabrica un certificat per a `www.google.com` amb el nom amistós `Google de mentida`, llista els certificats de l'equip (subjecte = emissor) i després esborra'l:
> ```powershell
> New-SelfSignedCertificate -DnsName www.google.com -CertStoreLocation Cert:\LocalMachine\My -FriendlyName "Google de mentida"
> Get-ChildItem Cert:\LocalMachine\My | Format-Table FriendlyName, Subject, Issuer -AutoSize
> Get-ChildItem Cert:\LocalMachine\My | Where-Object FriendlyName -eq "Google de mentida" | Remove-Item -DeleteKey
> ```
> Tenir aquest certificat no et converteix en Google. Cap navegador del món confiaria en qui l'ha signat.

---

## Nivell 4 — El motlle

> Creem la plantilla **WebServer-SAN** a partir de la plantilla *Servidor web* i la publiquem a ORBITA-CA. Abans de demanar el certificat oficial, preparem el motlle amb què ORBITA-CA farà els certificats de les webs de l'empresa.

> 💡 **Per què una plantilla nova.** Les plantilles que porta Windows no es poden modificar; per canviar-les se'n fa una còpia. A més, els navegadors només accepten un certificat si el nom de la web surt al camp **SAN**. Amb aquesta plantilla, el nom i el SAN els escriurem nosaltres a la sol·licitud.

**SERVIDOR · Part A · Duplicar la plantilla**

1. <kbd>Win</kbd>+<kbd>R</kbd> → `certtmpl.msc`. S'obre la *Consola de plantillas de certificado*.
2. Clic dret sobre *Servidor web* › *Plantilla duplicada*.
3. Pestanya *Compatibilidad*: a *Entidad de certificación* tria `Windows Server 2016`, i a *Destinatario del certificado* tria `Windows 10/Windows Server 2016`. Cada canvi obre una finestra que explica què comporta; prem *Aceptar*.
4. Pestanya *General*: a *Nombre para mostrar de la plantilla* escriu `WebServer-SAN` (el *Nombre de plantilla* s'omple sol). Posa el *Período de validez* a `2` *Años* i deixa **desmarcat** *Publicar certificado en Active Directory*.
5. Pestanya *Nombre del sujeto*: comprova que està marcat *Proporcionado por el solicitante* (vol dir que el nom l'escriurà qui demani el certificat; serem nosaltres, al nivell 5).
6. Pestanya *Seguridad*: prem *Agregar…*, escriu `Equipos del dominio`, *Comprobar nombres* i *Aceptar*. Amb *Equipos del dominio* seleccionat, marca *Permitir* a *Leer* i *Inscribirse*.
7. Encara a *Seguridad*, selecciona *Admins. del dominio* i comprova que té *Leer*, *Escribir* i *Inscribirse*.
8. Prem *Aceptar*. La plantilla *WebServer-SAN* apareix a la llista.

**SERVIDOR · Part B · Publicar-la a la CA**

9. Torna a `certsrv.msc` i obre ORBITA-CA. Clic dret sobre *Plantillas de certificado* › *Nuevo › Plantilla de certificado para emitir*.
10. Selecciona *WebServer-SAN* i prem *Aceptar*. Apareix a la llista, al costat de *Servidor web*, *Equipo*, *Usuario* i les altres que ORBITA-CA ja emetia.

> ⚠️ **El pas que tothom s'oblida.** Crear la plantilla no n'hi ha prou. Si no la publiques a la CA, ORBITA-CA no la coneix i al nivell 5 la sol·licitud fallarà amb l'error `CERTSRV_E_UNSUPPORTED_CERT_TYPE`. Si *WebServer-SAN* no surt a la llista per publicar, tanca `certsrv.msc`, espera una mica i torna-hi.

> **Captura 5:** la carpeta *Plantillas de certificado* de `certsrv.msc` amb *WebServer-SAN* publicada.

![Captura 5 — WebServer-SAN publicada a la CA]({{ '/assets/practiques/03-entitat-certificadora-ad/captura5.png' | relative_url }})

> **Repte 4 (captura 5b):** a `certtmpl.msc`, obre les propietats de *WebServer-SAN*, ves a la pestanya *Extensiones* i selecciona *Directivas de aplicación*. Fes una captura de l'ús que surt. Aquest ús és el que diu que el certificat serveix per identificar un servidor, i no per signar scripts.

---

## Nivell 5 — La sol·licitud

> Fem la sol·licitud del certificat de la web amb un fitxer `.inf` i `certreq`, l'enviem a ORBITA-CA i l'instal·lem al servidor. Ara demanem el DNI oficial de la web: primer omplim el formulari, després l'enviem a la policia i, quan ens el torna signat, el guardem al calaix.

**SERVIDOR · Part A · La recepta**

1. Al PowerShell d'administrador, crea una carpeta per a la feina i un fitxer buit:

   ```powershell
   mkdir C:\certs
   cd C:\certs
   New-Item web.inf -ItemType File
   notepad web.inf
   ```

2. Escriu-hi la recepta del certificat i desa amb <kbd>Ctrl</kbd>+<kbd>S</kbd>:

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

   Què vol dir cada línia:

   | Línia | Què vol dir |
   |---|---|
   | `Subject` | El nom del certificat |
   | `FriendlyName` | El nom amistós, per distingir-lo del de pega a IIS |
   | `KeyLength` · `KeyAlgorithm` | Una clau RSA de 2048 bits |
   | `KeyUsage = 0xa0` | La clau servirà per signar (`0x80`) i per xifrar claus (`0x20`). És el que necessita HTTPS |
   | `MachineKeySet = TRUE` | La clau es guarda a l'**equip** i no a l'usuari, perquè IIS la pugui fer servir |
   | `2.5.29.17` | El número (OID) del camp **SAN**. A la línia de sota hi va el nom, `dns=control.orbita.cat` |
   | `CertificateTemplate` | La plantilla que ha de fer servir ORBITA-CA. Ha de ser el nom exacte |

**SERVIDOR · Part B · Demanar, enviar i acceptar**

3. Crea la sol·licitud a partir de la recepta:

   ```powershell
   certreq -new web.inf web.req
   ```

   En aquest moment s'ha creat la parella de claus, i la privada s'ha quedat guardada al servidor.
4. (Opcional) Mira què hi ha dins de la sol·licitud; és el CSR codificat en text, amb el nom i la clau pública, mai la privada:

   ```powershell
   Get-Content web.req
   ```

5. Envia la sol·licitud a ORBITA-CA:

   ```powershell
   certreq -submit web.req web.cer
   ```

   S'obre una finestra amb la llista d'entitats certificadores. Selecciona *ORBITA-CA* i prem *Aceptar*. A la consola surt el número de sol·licitud i que el certificat s'ha emès (*Emitido*). El fitxer `web.cer` és el certificat signat.
6. Instal·la el certificat:

   ```powershell
   certreq -accept web.cer
   ```

   Si no surt cap error, el certificat ja és al magatzem de l'equip, unit a la seva clau privada.

**SERVIDOR · Part C · Els dos cadenats, cara a cara**

7. Llista els certificats de l'equip que es diuen `control.orbita.cat`:

   ```powershell
   Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -eq "CN=control.orbita.cat" | Format-List FriendlyName, Subject, Issuer, DnsNameList, NotAfter
   ```

   Sortiran els dos: el *Cadenat de pega* (emissor `CN=control.orbita.cat`, es signa ell mateix) i el *Cadenat oficial* (emissor `CN=ORBITA-CA, DC=orbita, DC=cat`). Tenen el mateix nom i el mateix SAN; l'única diferència és **qui els signa**.

> 💡 El certificat oficial no és millor per dins, i xifra igual. La diferència és qui el signa. I això ho canvia tot.

> ⚠️ Si `certreq -submit` dona l'error `CERTSRV_E_UNSUPPORTED_CERT_TYPE`, no has publicat la plantilla: torna al nivell 4, part B. Si diu que no troba la plantilla, revisa que a `web.inf` hi hagi `WebServer-SAN` escrit exactament igual.

> **Captura 6:** la sortida de l'últim `Get-ChildItem`, amb els dos certificats i els seus emissors.

![Captura 6 — cadenat de pega vs cadenat oficial]({{ '/assets/practiques/03-entitat-certificadora-ad/captura6.png' | relative_url }})

> **Repte 5 (captura 6b):** a `certsrv.msc`, obre *Certificados emitidos* i busca el certificat que acabes de demanar, el de la plantilla *WebServer-SAN*. Obre'l amb doble clic, ves a la pestanya *Detalles* i busca el camp on surt `control.orbita.cat` com a nom DNS. Fes-ne una captura.

---

## Nivell 6 — El cadenat oficial

> Canviem el certificat de pega pel certificat oficial a IIS i comprovem que el client mostra el cadenat. Arriba el moment: treiem el cadenat de pega de la porta i hi posem el que ha signat ORBITA-CA.

**SERVIDOR · Part A · Canviar el certificat**

1. A l'administrador d'IIS, ves a *Default Web Site* i prem *Enlaces…*.
2. Selecciona la línia `https` i prem *Modificar…*.
3. A *Certificado SSL*, tria *Cadenat oficial*. Si vols, prem *Ver…* per comprovar que l'ha emès ORBITA-CA. Prem *Aceptar* i *Cerrar*.

**CLIENT · Part B · El cadenat**

4. Al client, obre una finestra privada d'Edge (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd>) i ves a `https://control.orbita.cat`. La web surt a la primera, sense cap avís. A l'esquerra de l'adreça hi ha el **cadenat**.
5. Fes clic al cadenat, després a la línia que diu que la connexió és segura, i obre el certificat. Està emès per a `control.orbita.cat` i l'emissor és **ORBITA-CA**.
6. Al visor del certificat, ves a la pestanya *Detalles* (o *Ruta de certificación*). A dalt hi ha la jerarquia, amb ORBITA-CA a dalt i `control.orbita.cat` a sota. És la cadena de confiança del resum, apartat [1.3](#13-la-cadena-de-confiança).

> 💡 Edge mostra el cadenat perquè es compleixen quatre coses alhora:
> 1. El certificat l'ha signat ORBITA-CA.
> 2. ORBITA-CA és a la llista de confiança del client (hi va arribar al nivell 1).
> 3. El nom de l'adreça, `control.orbita.cat`, surt al SAN.
> 4. El certificat no ha caducat ni està revocat.
>
> Si en falla una, surt l'avís.

> 💡 **I des de casa?** Un ordinador que no és del domini, com el teu portàtil, no té ORBITA-CA a la seva llista i veuria l'avís. Per això les webs d'Internet fan servir CA públiques, com Let's Encrypt o DigiCert, que ja venen instal·lades als navegadors i als sistemes operatius.

> **Captura 7:** Edge amb la web i el cadenat, i el visor del certificat amb la jerarquia ORBITA-CA › `control.orbita.cat`.

![Captura 7 — web amb cadenat oficial]({{ '/assets/practiques/03-entitat-certificadora-ad/captura7-cadenat.png' | relative_url }})

I el visor del certificat, emès per a `control.orbita.cat` i signat per **ORBITA-CA**:

![Captura 7 — visor del certificat (Emès per ORBITA-CA)]({{ '/assets/practiques/03-entitat-certificadora-ad/captura7-certificat.png' | relative_url }})

> **Repte 6 (captura 7b):** recordes els tres noms del repte 2? Obre `https://10.0.2.6` i `https://dc-orbita.orbita.cat` en una finestra privada. Ara surt un avís. Prem el botó d'opcions avançades i fes una captura del codi d'error. Per què passa, si el certificat és oficial? Mira la condició 3 de la idea clau: el certificat només val per al nom `control.orbita.cat`, que és l'únic que hi ha al SAN.
>
> Per acceptar més noms, a `web.inf` es poden posar separats amb `&`, per exemple `_continue_ = "dns=control.orbita.cat&dns=intranet.orbita.cat"`.

---

## Captures a lliurar

Al final de la pràctica cal lliurar les captures numerades. Les dels **reptes** porten el número amb una `b`.

| Captura | Màquina | Què s'hi ha de veure |
|---|---|---|
| **1** | CLIENT | `whoami` i els dos `nslookup` (nivell 0) |
| **1b** | SERVIDOR | DNS amb reenviadors i zona `orbita.cat` amb `dc-orbita` (repte 0) |
| **2** | SERVIDOR + CLIENT | `certsrv.msc` amb ORBITA-CA i `certlm.msc` amb ORBITA-CA de confiança (nivell 1) |
| **2b** | SERVIDOR | *Ruta de certificación* d'ORBITA-CA amb un sol nivell (repte 1) |
| **3** | CLIENT | Edge amb la web i l'avís *No seguro* (nivell 2) |
| **3b** | CLIENT | Tres pestanyes: `10.0.2.6`, `dc-orbita.orbita.cat`, `control.orbita.cat` (repte 2) |
| **4** | CLIENT | Avís d'Edge `NET::ERR_CERT_AUTHORITY_INVALID` (nivell 3) |
| **4b** | SERVIDOR | Certificat `www.google.com` de pega, subjecte = emissor (repte 3) |
| **5** | SERVIDOR | *Plantillas de certificado* amb *WebServer-SAN* publicada (nivell 4) |
| **5b** | SERVIDOR | *WebServer-SAN* › *Extensiones* › *Directivas de aplicación* (repte 4) |
| **6** | SERVIDOR | `Get-ChildItem` amb els dos certificats i els seus emissors (nivell 5) |
| **6b** | SERVIDOR | *Certificados emitidos* amb el camp DNS `control.orbita.cat` (repte 5) |
| **7** | CLIENT | Edge amb cadenat i visor amb jerarquia ORBITA-CA › `control.orbita.cat` (nivell 6) |
| **7b** | CLIENT | Avís en obrir els altres dos noms per HTTPS (repte 6) |

> Les imatges van a `assets/practiques/03-entitat-certificadora-ad/`. Per enllaçar-les al document, el patró és:
> `![text alternatiu]({{ '/assets/practiques/03-entitat-certificadora-ad/captura1.png' | relative_url }})`

**No esborris res.** Fes una instantània de les dues màquines amb el nom *Web amb HTTPS*: ho necessitaràs tot a la 2a part, *Carnets digitals per a l'equip*.
