# Présentation
Ptit café est un projet de sécurisation automatique de serveur web. Son nom vient en effet de la fainéantise des informaticiens, grâce à ce projet, ils peuvent aller prendre un ptit café en attendant que leur travail se fasse tout seul.
Ce script installera un serveur web classique, le sécurisera, et y configurera un reverse proxy.

# Technos
## Web
- Apache
- Mariadb
- PHP
## Séurisation réseau
- Fail2ban
- SSH
- Pare-feu
- SSL (avec let's encrypt)
## Reverse proxy
- Nginx

# Installation centos 7
## Clone du repo
- `yum install git`
- `git clone https://github.com/Joktaa/ptit-cafe.git`

## Lancement
- `./ptit-cafe/ptit-cafe.sh`

## Test
- `curl localhost`
