# Réponses aux questions — TD Jour 1

## Partie 1 — Explorer le VPC par défaut

**Q1 : Quelle est la plage d'adresses du VPC par défaut ?**
172.31.0.0/16. Ses sous-réseaux sont qualifiés de "publics" car leur table de routage contient une route `0.0.0.0/0 → igw-xxx` (Internet Gateway), ce qui permet au trafic Internet d'entrer et de sortir.

**Q2 : Sans sous-réseau privé, comment rendre une instance injoignable depuis Internet ?**
En ne lui attribuant pas d'IP publique. Sans adresse IP publique, aucune connexion entrante depuis Internet ne peut l'atteindre, même si elle se trouve dans un sous-réseau public.

---

## Partie 2 — Deux instances EC2

**Q1 : Laquelle est joignable depuis Internet ?**
Uniquement le bastion, car lui seul possède une IP publique. La cible, sans IP publique, n'est pas routable depuis Internet même si le sous-réseau est public.

**Q2 : Comment atteindre la cible sans IP publique ?**
En rebondissant via le bastion : SSH vers le bastion → SSH vers l'IP privée de la cible (172.31.x.x).

---

## Partie 3 — Security Groups

**Q1 : Pourquoi définir la source de sg-cible comme "sg-bastion" plutôt qu'une plage d'IP ?**
Référencer le SG source rend la règle dynamique et robuste : toute instance portant sg-bastion est autorisée, sans dépendre d'IPs qui peuvent changer (reboot, nouvelle instance, etc.).

**Q2 : Pourquoi la réponse repart-elle sans règle de sortie explicite ?**
Le Security Group est stateful : il mémorise la connexion entrante autorisée et laisse repartir la réponse automatiquement, sans règle de sortie nécessaire.

---

## Partie 4 — NACL

**Q1 : Pourquoi autoriser en sortie la plage 1024–65535 et non le port 22 ?**
Lors d'une connexion SSH, le client se connecte depuis un port éphémère (1024–65535). La réponse du serveur part du port 22 vers ce port éphémère du client. La NACL étant stateless, ce trafic retour doit être explicitement autorisé en sortie sur la plage des ports éphémères.

**Q2 : Différence entre Security Group et NACL ?**
Le Security Group est stateful (le trafic retour est autorisé automatiquement), tandis que la NACL est stateless (il faut autoriser explicitement l'aller ET le retour).

---

## Partie 5 — Défense en profondeur

**Q1 : Si le SG autorise mais que la NACL refuse, le trafic passe-t-il ?**
Non. Le paquet doit franchir la NACL (sous-réseau) ET le Security Group (instance). Un refus à l'une des deux couches suffit à bloquer le trafic.

**Q2 : Avantage concret de deux couches de filtrage ?**
Si une couche est mal configurée ou contournée, l'autre protège encore. De plus, la NACL permet de bloquer une IP pour tout un sous-réseau d'un coup, ce qu'un Security Group ne peut pas faire (il ne sait que refuser, pas bloquer au niveau subnet).

---

## Bonnes pratiques retenues

- **Moindre privilège** : SSH limité à son IP personnelle uniquement (jamais `0.0.0.0/0`)
- **Bastion** : ne jamais exposer directement les serveurs, passer par un point d'entrée unique
- **Source = SG** : référencer un Security Group comme source plutôt qu'une plage d'IP
- **Défense en profondeur** : combiner NACL (subnet) + Security Group (instance)
- **NACL stateless** : toujours penser aux ports éphémères (1024–65535) pour le trafic retour
- **Nettoyage** : supprimer ses propres ressources, ne jamais toucher au VPC par défaut ni aux ressources des autres
