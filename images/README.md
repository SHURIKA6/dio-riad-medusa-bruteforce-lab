# Prints / Evidências

Coloque nesta pasta (`images/`) os prints das etapas do lab. Sugestão de nomes:

| Arquivo | O que mostrar |
|---|---|
| `01-vbox-rede.png` | Configuração de rede das VMs no VirtualBox (NAT / Host-Only / Bridge) |
| `02-nmap-scan.png` | Resultado do `nmap` contra a Metasploitable (portas 21, 80, 445 abertas) |
| `03-medusa-ftp-sucesso.png` | Medusa encontrando credencial válida no FTP (porta 21) |
| `04-dvwa-low.png` | DVWA com nível de segurança em Low (página de setup / Brute Force) |
| `05-medusa-dvwa.png` | Medusa com sucesso no login do DVWA (módulo http-form-brute) |
| `06-medusa-smb.png` | Medusa com sucesso no SMB (porta 445) |
| `07-smbclient-validacao.png` | Validação com `smbclient -L` ou acesso ao share usando a credencial encontrada |

Dicas:
- Use PNG ou JPG, largura mínima 1280px para ficar legível.
- Oculte IPs públicos / dados sensíveis, se houver.
- Mantenha os mesmos nomes acima para o README principal referenciar corretamente.
