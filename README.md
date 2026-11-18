# GS CitizenTech — Infraestrutura Linux com Shell Script

## INTEGRANTES
Guilherme Oliveira Da Silva -  558797
Rafael Panhoca - 555014
Matheus Dantas - 558804
Victor rodriguez – 559094
Silas Alves  - 555020


Ambiente Linux automatizado para hospedar o **Colecity** (API Spring Boot + front React), com scripts Bash, serviços systemd, limites de recursos, monitoramento de CPU/memória/disco e logs.

Cada container é tratado como uma **máquina virtual**: a imagem `redhat/ubi9-init` (Red Hat UBI 9) traz só o Linux e o systemd. Todo o resto é instalado pelos scripts.

## Arquitetura

```
 Sua máquina                    rede Docker "citizentech-net" (192.28.0.0/24)
 ┌───────────────────┐        ┌──────────────────────────────────────────────────────┐
 │ navegador         │        │  app (192.28.0.30)              api (192.28.0.20)    │
 │ localhost:8080 ───┼───────►│  nginx :80 ──── /api/ ────────► Spring Boot :8080    │
 │ localhost:8090 ───┼───────►│ ──────────── acesso direto ───► Spring Boot :8080    │
 │                   │        │  citizentech-app (nginx)        citizentech-api      │
 │ add-arquivos-*.sh │        │  monitor.service                monitor.service      │
 │ teste-carga.sh    │        │  volume: app-logs               volume: api-logs     │
 └───────────────────┘        └──────────────────────────────────────────────────────┘
```

| Porta na sua máquina | Vai para              | Uso                                         |
| -------------------- | --------------------- | ------------------------------------------- |
| `localhost:8080`     | app, porta 80 (nginx) | front React; `/api/` é repassado para a API |

## Estrutura do repositório

```
gs-citizentech/
├── docker-compose.yml                    # containers, rede, IPs, portas, volumes
├── add-arquivos-api.sh                   # [sua máquina] copia os arquivos para o container api
├── add-arquivos-app.sh                   # [sua máquina] copia os arquivos para o container app
├── teste-carga.sh                        # [sua máquina] estoura a API com requisições
├── scripts/
│   ├── shared/                           # usados nos dois containers
│   │   ├── setup-host.sh                 #   prepara o SO
│   │   └── monitor.sh                    #   monitoramento de CPU, memória e disco
│   ├── api/
│   │   ├── download-dependencias-api.sh  #   instala o Java 21
│   │   └── deploy-api.sh                 #   instala o .jar e inicia o serviço
│   └── app/
│       ├── download-dependencias-app.sh  #   instala o nginx
│       └── deploy-app.sh                 #   publica o React e inicia o serviço
├── systemd/
│   ├── monitor.service
│   ├── citizentech-api.service           # API: reinício automático + limites
│   └── citizentech-app.service           # nginx: reinício automático + limites
├── config/
│   ├── api.env                           # variáveis de ambiente da API
│   └── nginx.conf
├── sample-apps/                          # Colecity (API e front)
└── evidencias/                           # prints para a entrega
```

Dentro dos containers os scripts ficam todos na mesma pasta, `/opt/citizentech/scripts/`. A divisão em `shared/`, `api/` e `app/` existe só no repositório.

## Passo a passo

Todos os comandos são executados na pasta do projeto. Para cada container a ordem é sempre:

```
add-arquivos-*.sh  →  setup-host.sh  →  download-dependencias-*.sh  →  deploy-*.sh
 (copia arquivos)     (prepara o SO)     (instala Java ou nginx)        (instala e inicia a aplicação)
```

### 1. Subir os containers

```bash
docker compose up -d
docker compose ps
```

### 2. Gerar os artefatos das aplicações

Com Java 21 + Maven e Node instalados na sua máquina:

```bash
(cd sample-apps/api-springboot && mvn -DskipTests clean package)   # gera target/app.jar
(cd sample-apps/app-react && npm install && npm run build)          # gera dist/
```

### 3. Container api

```bash
./add-arquivos-api.sh
docker exec api bash /opt/citizentech/scripts/setup-host.sh
docker exec api bash /opt/citizentech/scripts/download-dependencias-api.sh
docker exec api bash /opt/citizentech/scripts/deploy-api.sh
```

### 4. Container app

```bash
./add-arquivos-app.sh
docker exec app bash /opt/citizentech/scripts/setup-host.sh
docker exec app bash /opt/citizentech/scripts/download-dependencias-app.sh
docker exec app bash /opt/citizentech/scripts/deploy-app.sh
```

Rodar o `setup-host.sh` de novo não faz nada: ele registra que já foi executado e sai.

### 5. Acessar

```bash
open http://localhost:8080                  # front (React servido pelo nginx)
curl http://localhost:8080/api/painel       # API passando pelo nginx do app
```

Para atualizar só a aplicação (sem reinstalar dependências):

```bash
./add-arquivos-api.sh && docker exec api bash /opt/citizentech/scripts/deploy-api.sh
./add-arquivos-app.sh && docker exec app bash /opt/citizentech/scripts/deploy-app.sh
```

Para usar as aplicações reais, passe o caminho do artefato: `./add-arquivos-api.sh ../meu-backend/target/app.jar` ou `./add-arquivos-app.sh ../meu-front/dist`.

## Usuários e permissões

| Usuário / grupo     | Para quê                                                   | Shell                                       |
| ------------------- | ---------------------------------------------------------- | ------------------------------------------- |
| grupo `citizentech` | pode escrever em `/var/log/citizentech`                    | —                                           |
| `monitor`           | roda o `monitor.sh`                                        | `/sbin/nologin` (ninguém faz login com ele) |
| `springboot`        | roda a API                                                 | `/sbin/nologin`                             |
| `nginx`             | atende as requisições do front (processos worker do nginx) | criado pelo pacote do nginx                 |

| Caminho                        | Permissão              | Por quê                                       |
| ------------------------------ | ---------------------- | --------------------------------------------- |
| `/var/log/citizentech`         | `775 root:citizentech` | serviços do grupo podem gravar logs           |
| `/opt/citizentech/api/app.jar` | `640 root:citizentech` | a API lê o `.jar`, mas não consegue alterá-lo |
| `/etc/citizentech/api.env`     | `640 root:citizentech` | variáveis visíveis só para o grupo            |
| `/opt/citizentech/www`         | `755 root:root`        | o nginx só precisa ler                        |

## Serviços systemd

| Serviço                   | Container | Reinício automático   | Limite de memória                    | Limite de CPU                |
| ------------------------- | --------- | --------------------- | ------------------------------------ | ---------------------------- |
| `monitor.service`         | api e app | `Restart=always` (5s) | —                                    | —                            |
| `citizentech-api.service` | api       | `Restart=always` (5s) | `MemoryMax=512M` (heap Java: 256 MB) | `CPUQuota=100%` (1 núcleo)   |
| `citizentech-app.service` | app       | `Restart=always` (5s) | `MemoryMax=128M`                     | `CPUQuota=50%` (meio núcleo) |

O `citizentech-app.service` substitui o `nginx.service` que vem no pacote, porque aquele não reinicia sozinho nem tem limites. Ele também valida o `nginx.conf` antes de iniciar (`ExecStartPre=nginx -t`).

**Como os limites se comportam:**

- **Memória (`MemoryMax`):** se o processo passar do limite, o kernel o encerra e o systemd reinicia.
- **CPU (`CPUQuota`):** o processo nunca é encerrado por usar CPU demais; ele fica mais lento.
- **API (`-XX:+ExitOnOutOfMemoryError`):** quando o heap de 256 MB acaba, a JVM encerra em vez de continuar rodando com erro, e o systemd reinicia.

```bash
docker exec -it api bash                                      # "entrar na máquina"
systemctl status citizentech-api                              # estado, PID, memória e CPU usadas
systemctl show citizentech-api -p MemoryMax -p CPUQuotaPerSecUSec   # limites aplicados
systemctl stop|start|restart citizentech-api                  # ciclo de vida
journalctl -u citizentech-api -n 20                           # histórico do systemd
docker exec app systemctl status citizentech-app              # front
docker exec app systemctl reload citizentech-app              # relê o nginx.conf sem derrubar
```

Todos os serviços estão habilitados (`enable`), então iniciam sozinhos quando o container sobe.

## Logs

Ficam em `/var/log/citizentech/` dentro de cada container, gravados no volume (não se perdem se o container for recriado).

| Arquivo                                         | Conteúdo                                                        |
| ----------------------------------------------- | --------------------------------------------------------------- |
| `setup-host.log`                                | cada etapa do setup, saída do `dnf` e resultado (SUCESSO/FALHA) |
| `dependencias-api.log` / `dependencias-app.log` | instalação do Java / nginx                                      |
| `deploy-api.log` / `deploy-app.log`             | cada etapa do deploy, limites aplicados e resultado             |
| `monitor.log`                                   | uma linha por verificação: `CPU=12% MEM=40% DISCO=30%`          |
| `alerts.log`                                    | só os alertas de consumo elevado                                |
| `api.log`                                       | saída da API Spring Boot                                        |
| `app.log`                                       | saída do serviço do nginx                                       |
| `nginx-access.log` / `nginx-error.log`          | acessos e erros do nginx                                        |

```bash
docker exec api tail -f /var/log/citizentech/monitor.log
docker exec api cat /var/log/citizentech/alerts.log
docker exec api grep ERRO /var/log/citizentech/setup-host.log
```

## Testes de falha

**1. Parar e reiniciar o monitoramento**

```bash
docker exec api systemctl stop monitor
docker exec api systemctl status monitor     # inactive (parado pelo admin, não volta sozinho)
docker exec api systemctl start monitor
docker exec api tail -n 5 /var/log/citizentech/monitor.log
```

**2. Matar processos (simula um crash)**

```bash
docker exec api systemctl kill -s KILL monitor
docker exec app systemctl kill -s KILL citizentech-app
sleep 7
docker exec api systemctl status monitor                # active (running) com novo PID
docker exec app systemctl status citizentech-app        # active (running) com novo PID
docker exec app journalctl -u citizentech-app -n 5      # "Scheduled restart job"
```

**3. Sobrecarga da API por requisições** (estoura a memória e o systemd reinicia)

```bash
./teste-carga.sh
```

O script dispara requisições em lotes para o app (`localhost:8080`), que repassa para a API. Cada requisição guarda 200 KB na memória da API. Ao passar do limite, a JVM encerra e o systemd reinicia o processo. O script mostra o PID antes e depois, o contador de reinícios, o histórico do systemd e o erro `OutOfMemoryError` no `api.log`.

Os dados registrados em memória se perdem no reinício: a API volta só com os exemplos.
