# TD2 — Filtrage Réseau AWS & Suricata IDS

**Student ID :** 99  
**Région :** eu-west-3 (Paris)  
**VPC :** vpc-0ebcdb39f7a526ef9

## Infrastructure déployée

| Ressource | IP publique | IP privée | Utilisateur |
|-----------|-------------|-----------|-------------|
| Bastion   | 35.181.173.29 | 172.31.55.61 | ec2-user |
| Sonde Suricata | 15.236.95.183 | 172.31.55.245 | ubuntu |

Clé SSH : `td2-99-key.pem` (dans ce répertoire)

---

## 1. Déploiement Terraform

```bash
# Depuis c:/MASTER2/CLOUD/AWS/infra3/
make init      # terraform init
make plan      # vérifier ce qui sera créé
make apply     # déployer l'infrastructure
```

Récupérer les IPs après apply :

```bash
terraform output bastion_ip
terraform output sonde_public_ip
terraform output sonde_private_ip
```

---

## 2. Connexion SSH

### Prérequis — vérifier que ~/.ssh/config contient :

```
Host bastion-td2
  HostName 35.181.173.29
  User ec2-user
  IdentityFile c:/MASTER2/CLOUD/AWS/infra3/td2-99-key.pem
  StrictHostKeyChecking no

Host sonde-td2
  HostName 15.236.95.183
  User ubuntu
  IdentityFile c:/MASTER2/CLOUD/AWS/infra3/td2-99-key.pem
  ProxyJump bastion-td2
  StrictHostKeyChecking no
```

### Connexion au bastion

```bash
ssh bastion-td2
```

### Connexion à la sonde (via alias)

```bash
ssh sonde-td2
```

### Connexion à la sonde (commande directe, sans alias)

```bash
# Option 1 : depuis votre machine avec ProxyJump
ssh -i "c:/MASTER2/CLOUD/AWS/infra3/td2-99-key.pem" \
    -J ec2-user@35.181.173.29 \
    ubuntu@15.236.95.183

# Option 2 : depuis le bastion (après avoir copié la clé)
scp -i "c:/MASTER2/CLOUD/AWS/infra3/td2-99-key.pem" \
    "c:/MASTER2/CLOUD/AWS/infra3/td2-99-key.pem" \
    ec2-user@35.181.173.29:/tmp/td2-99-key.pem

ssh bastion-td2
# puis depuis le bastion :
chmod 400 /tmp/td2-99-key.pem
ssh -i /tmp/td2-99-key.pem ubuntu@172.31.55.245
```

---

## 3. Test du bastion

```bash
# Vérifier que SSH fonctionne
ssh bastion-td2 "hostname && id"

# Vérifier les Security Groups (depuis le bastion, ping internet bloqué vers l'extérieur via sg)
ssh bastion-td2 "curl -s --max-time 5 https://ifconfig.me"

# Depuis le bastion, tester la connectivité vers la sonde
ssh bastion-td2 "ping -c 4 172.31.55.245"
```

---

## 4. Test Suricata IDS

Ouvrir **deux terminaux en parallèle**.

### Terminal 1 — Surveiller les alertes sur la sonde

```bash
# Se connecter à la sonde
ssh sonde-td2

# Vérifier que Suricata tourne
sudo systemctl status suricata

# Si Suricata n'est pas encore installé (user_data en cours)
sudo tail -50 /var/log/cloud-init-output.log

# Surveiller les alertes en temps réel
sudo tail -f /var/log/suricata/eve.json | grep TD2

# Voir toutes les alertes (event_type=alert)
sudo grep '"event_type":"alert"' /var/log/suricata/eve.json

# Voir les alertes formatées lisiblement
sudo cat /var/log/suricata/eve.json | python3 -m json.tool | grep -A 10 '"alert"'
```

### Terminal 2 — Générer du trafic ICMP depuis le bastion

```bash
# Se connecter au bastion
ssh bastion-td2

# Envoyer des pings vers la sonde (déclenche la règle ICMP)
ping -c 10 172.31.55.245
```

Les alertes apparaissent dans le Terminal 1 avec le message `"TD2 ICMP detecte"`.

---

## 5. Remontée de logs Suricata

### Voir eve.json en direct

```bash
# Sur la sonde — alertes uniquement
sudo tail -f /var/log/suricata/eve.json | grep -v '"event_type":"stats"'

# Filtrer par type d'événement
sudo tail -f /var/log/suricata/eve.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        if e.get('event_type') == 'alert':
            print(f\"[ALERTE] {e['timestamp']} | {e['src_ip']} -> {e['dest_ip']} | {e['alert']['signature']}\")
    except: pass
"
```

### Logs système Suricata

```bash
# Journal systemd
sudo journalctl -u suricata -f

# Log d'installation (user_data)
sudo cat /var/log/cloud-init-output.log

# Règles chargées
sudo cat /var/lib/suricata/rules/suricata.rules | grep TD2

# Stats Suricata
sudo tail -1 /var/log/suricata/eve.json | python3 -m json.tool
```

### Vérifier la règle personnalisée

```bash
# Sur la sonde
sudo grep -n TD2 /var/lib/suricata/rules/suricata.rules
# Attendu : alert icmp any any -> $HOME_NET any (msg:"TD2 ICMP detecte"; sid:1000001; rev:1;)

# Tester la configuration Suricata
sudo suricata -T -c /etc/suricata/suricata.yaml
```

---

## 6. Destruction de l'infrastructure

```bash
make destroy
# ou
terraform destroy -auto-approve
```

---

## Résumé des commandes Make

| Commande | Action |
|----------|--------|
| `make init` | Initialise Terraform |
| `make plan` | Prévisualise les changements |
| `make apply` | Déploie l'infrastructure |
| `make inventory` | Génère l'inventaire Ansible |
| `make destroy` | Détruit toutes les ressources |
