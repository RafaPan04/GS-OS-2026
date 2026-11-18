#!/bin/bash
# =============================================================================
# setup-host.sh - prepara o sistema operacional do container.
# Roda DENTRO do container (api ou app):
#
#   docker exec api bash /opt/citizentech/scripts/setup-host.sh
#
# O que faz:
#   1. confere se já foi executado (se sim, não faz nada)
#   2. confere e registra hostname, IP e DNS
#   3. instala pacotes básicos
#   4. configura timezone e variáveis de ambiente
#   5. cria grupo, usuário e permissões
#   6. instala e inicia o serviço de monitoramento (systemd)
# =============================================================================

LOG_DIR=/var/log/citizentech
LOG_FILE=$LOG_DIR/setup-host.log
FLAG_FILE=/var/lib/citizentech/setup.ok
BASE_DIR=/opt/citizentech

mkdir -p $LOG_DIR

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOSTNAME] $1" | tee -a $LOG_FILE
}

erro() {
  log "ERRO: $1"
  log "===== FIM do setup: FALHA ====="
  exit 1
}

log "===== INICIO do setup ====="


# 1. Verifica se ja foi executado)
if [ -f $FLAG_FILE ]; then
  log "Setup já executado em: $(cat $FLAG_FILE). Nada a fazer."
  exit 0
fi

# 2. Rede: hostname, IP e DNS são definidos no docker-compose.yml.
#    Aqui o script confere e registra os valores.
IP=$(grep -w "$HOSTNAME" /etc/hosts | head -1 | awk '{print $1}')
DNS=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
log "Hostname: $HOSTNAME | IP: $IP | DNS: $DNS"

getent hosts redhat.com > /dev/null || erro "DNS não resolve nomes externos"
log "DNS externo OK (redhat.com)"

# 3. Pacotes básicos
#    procps-ng = comandos free, vmstat, ps, top (usados no monitoramento)
log "Instalando pacotes: procps-ng tzdata"
dnf install -y procps-ng tzdata >> $LOG_FILE 2>&1 || erro "falha ao instalar pacotes"
log "Pacotes instalados"

# 4. Timezone e variáveis de ambiente
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime || erro "falha no timezone"
log "Timezone: America/Sao_Paulo"

cat > /etc/profile.d/citizentech.sh <<EOF
export CT_ENV=lab
export CT_NODE=$HOSTNAME
export CT_LOG_DIR=$LOG_DIR
EOF
log "Variáveis de ambiente criadas em /etc/profile.d/citizentech.sh"

# 5. Grupo, usuário e permissões
#    - grupo "citizentech": quem pode escrever nos logs
#    - usuário "monitor": roda o monitoramento, sem senha e sem shell (-s /sbin/nologin)
groupadd -f citizentech || erro "falha ao criar grupo citizentech"

if id monitor > /dev/null 2>&1; then
  log "Usuário monitor já existe"
else
  useradd -r -g citizentech -s /sbin/nologin monitor || erro "falha ao criar usuário monitor"
  log "Usuário monitor criado"
fi

mkdir -p /var/lib/citizentech
chown root:citizentech $LOG_DIR
chmod 775 $LOG_DIR                       # dono e grupo escrevem, outros só leem

touch $LOG_DIR/alerts.log
chown monitor:citizentech $LOG_DIR/alerts.log
chmod 664 $LOG_DIR/alerts.log

chmod 755 $BASE_DIR $BASE_DIR/scripts
chmod 755 $BASE_DIR/scripts/*.sh         # scripts executáveis
log "Diretórios e permissões configurados"

# 6. Serviço de monitoramento (systemd)
cp $BASE_DIR/systemd/monitor.service /etc/systemd/system/ || erro "monitor.service não encontrado"
systemctl daemon-reload
systemctl enable monitor.service >> $LOG_FILE 2>&1 || erro "falha ao habilitar monitor.service"
systemctl restart monitor.service || erro "falha ao iniciar monitor.service"

sleep 3
systemctl is-active monitor.service > /dev/null || erro "monitor.service não ficou ativo"
log "Serviço monitor.service ativo e habilitado no boot"

# Fim: grava o arquivo de controle
date > $FLAG_FILE
log "===== FIM do setup: SUCESSO ====="
