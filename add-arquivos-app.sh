#!/bin/bash
# =============================================================================
# add-arquivos-app.sh - copia para o container "app" todos os arquivos que ele
# precisa. Só copia: não instala nem executa nada.
# =============================================================================

cd "$(dirname "$0")" || exit 1           # vai para a pasta do projeto

CONTAINER=app
DESTINO=/opt/citizentech
DIST=${1:-sample-apps/app-react/dist}    # 1º argumento ou o padrão

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [add-arquivos-app] $1"
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

# Front
docker cp scripts/app/download-dependencias-app.sh  $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar download-dependencias-app.sh"
docker cp scripts/app/deploy-app.sh                 $CONTAINER:$DESTINO/scripts/ || erro "falha ao copiar deploy-app.sh"
docker cp systemd/citizentech-app.service           $CONTAINER:$DESTINO/systemd/ || erro "falha ao copiar citizentech-app.service"
docker cp config/nginx.conf                         $CONTAINER:$DESTINO/config/  || erro "falha ao copiar nginx.conf"

# Apaga o build anterior: se a pasta dist já existir, o docker cp colocaria
# o novo build DENTRO dela (dist/dist)
docker exec $CONTAINER rm -rf $DESTINO/dist
docker cp "$DIST"                                   $CONTAINER:$DESTINO/dist     || erro "falha ao copiar $DIST (gerou o build?)"

log "Arquivos copiados para $CONTAINER:$DESTINO"
