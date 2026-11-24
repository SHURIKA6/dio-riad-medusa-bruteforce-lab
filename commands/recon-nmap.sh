#!/bin/bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
WORDLIST_U="$BASEDIR/wordlists/users.txt"
WORDLIST_P="$BASEDIR/wordlists/passwords.txt"
# Recon inicial - Lab riad Medusa
# Uso: ./recon-nmap.sh 192.168.56.101
IP_MS2="${1:-<IP-MS2>}"
echo "[*] Alvo: $IP_MS2"

nmap -sV -O -p 21,22,80,139,445 "$IP_MS2"
nmap --script ftp-anon,smb-enum-users,http-title -p 21,80,445 "$IP_MS2"

echo "[*] Enum SMB:"
enum4linux -U "$IP_MS2" || echo "enum4linux não encontrado, instale com: sudo apt install enum4linux"
smbclient -L "//$IP_MS2" -N
