#!/bin/bash
# =============================================================================
# deploy-api.sh - instala o .jar e inicia a API Spring Boot no container "api".
# Roda DENTRO do container, depois do download-dependencias-api.sh:
#
#   docker exec api bash /opt/citizentech/scripts/deploy-api.sh
#
# O .jar é colocado em /opt/citizentech/app.jar pelo add-arquivos-api.sh.
# =============================================================================

LOG_FILE=/var/log/citizentech/deploy-api.log
JAR_RECEBIDO=/opt/citizentech/app.jar    # onde o add-arquivos-api.sh colocou o .jar
APP_DIR=/opt/citizentech/api             # onde a API fica instalada


log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOSTNAME] $1" | tee -a $LOG_FILE
}

erro() {
  log "ERRO: $1"
  log "===== FIM do deploy da API: FALHA ====="
  exit 1
}

log "===== INICIO do deploy da API ====="

# 1. Pré-requisitos
[ -f /var/lib/citizentech/setup.ok ] || erro "rode o setup-host.sh antes"
command -v java > /dev/null || erro "Java não instalado: rode o download-dependencias-api.sh antes"
[ -f $JAR_RECEBIDO ] || erro "arquivo $JAR_RECEBIDO não encontrado (rode o add-arquivos-api.sh)"

# 2. Usuário que vai rodar a API (sem shell, sem senha)
if id springboot > /dev/null 2>&1; then
  log "Usuário springboot já existe"
else
  useradd -r -g citizentech -s /sbin/nologin springboot || erro "falha ao criar usuário springboot"
  log "Usuário springboot criado"
fi

# 3. Arquivos da aplicação e permissões
#    dono root, grupo citizentech só lê: a API não consegue alterar o próprio .jar
mkdir -p $APP_DIR
cp $JAR_RECEBIDO $APP_DIR/app.jar || erro "falha ao copiar o .jar"
chown -R root:citizentech $APP_DIR
chmod 750 $APP_DIR
chmod 640 $APP_DIR/app.jar
log "Aplicação instalada em $APP_DIR/app.jar"

# 4. Variáveis de ambiente da API
mkdir -p /etc/citizentech
cp /opt/citizentech/config/api.env /etc/citizentech/api.env || erro "api.env não encontrado"
chown root:citizentech /etc/citizentech/api.env
chmod 640 /etc/citizentech/api.env
log "Variáveis de ambiente em /etc/citizentech/api.env"

# 5. Serviço systemd: inicia a API e mantém rodando
cp /opt/citizentech/systemd/citizentech-api.service /etc/systemd/system/ || erro "citizentech-api.service não encontrado"
systemctl daemon-reload
systemctl enable citizentech-api.service >> $LOG_FILE 2>&1 || erro "falha ao habilitar o serviço"
systemctl restart citizentech-api.service || erro "falha ao iniciar o serviço"
log "Serviço citizentech-api iniciado"
log "Limites: $(systemctl show citizentech-api -p MemoryMax -p CPUQuotaPerSecUSec | tr '\n' ' ')"

# 6. Healthcheck  
log "Aguardando a API responder em http://localhost:8080/actuator/health"
for i in $(seq 1 30); do
  if curl -s http://localhost:8080/actuator/health | grep -q UP; then
    log "API respondendo (status UP) na tentativa $i"
    log "===== FIM do deploy da API: SUCESSO ====="
    exit 0
  fi
  sleep 2
done

erro "API não respondeu em 60s. Veja /var/log/citizentech/api.log"
