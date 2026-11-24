# Mitigações - Lab riad Medusa

| Serviço | Risco demonstrado | Mitigação recomendada |
|---------|-------------------|------------------------|
| FTP (21) | Credencial fraca `msfadmin:msfadmin`, anon habilitado | Desabilitar FTP anon, usar SFTP/FTPS, senhas fortes + MFA, fail2ban, desabilitar serviço se não usado |
| Web DVWA (80) | Brute force sem rate-limit, senha `admin:password` | Rate-limit + CAPTCHA, lockout progressivo, MFA, política de senhas, WAF, logs centralizados |
| SMB (445) | Enumeração de usuários + spraying | SMB signing, desabilitar SMBv1, bloquear 445 na borda, LAPS, lockout, auditoria + SIEM, least privilege |

Medidas transversais: monitoramento (Fail2ban, Suricata), inventário, patching, backup, conscientização.
