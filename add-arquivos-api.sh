#!/bin/bash
# =============================================================================
# add-arquivos-api.sh - copia para o container "api" todos os arquivos que ele
# precisa. Só copia: não instala nem executa nada.
#
# =============================================================================

cd "$(dirname "$0")" || exit 1           # vai para a pasta do projeto

CONTAINER=api
DESTINO=/opt/citizentech
JAR=${1:-sample-apps/api-springboot/target/app.jar}   # 1º argumento ou o padrão

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [add-arquivos-api] $1"
}

erro() {
  log "ERRO: $1"
  exit 1
}

log "Copiando arquivos para o container $CONTAINER"

docker exec $CONTAINER mkdir -p $DESTINO/scripts $DESTINO/systemd $DESTINO/config \
  || erro "não foi possível acessar o container $CONTAINER (ele está rodando?)"

# Setup do sistema e monitoramento
docker cp scripts/shared/setup-host.sh              $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar setup-host.sh"
docker cp scripts/shared/monitor.sh                 $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar monitor.sh"
docker cp systemd/monitor.service                   $CONTAINER:$DESTINO/systemd/ || erro "falha ao copiar monitor.service"

# API
docker cp scripts/api/download-dependencias-api.sh  $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar download-dependencias-api.sh"
docker cp scripts/api/deploy-api.sh                 $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar deploy-api.sh"
docker cp systemd/citizentech-api.service           $CONTAINER:$DESTINO/systemd/ || erro "falha ao copiar citizentech-api.service"
docker cp config/api.env                            $CONTAINER:$DESTINO/config/  || erro "falha ao copiar api.env"
docker cp "$JAR"                                    $CONTAINER:$DESTINO/app.jar  || erro "falha ao copiar $JAR (gerou o .jar?)"

log "Arquivos copiados para $CONTAINER:$DESTINO"
