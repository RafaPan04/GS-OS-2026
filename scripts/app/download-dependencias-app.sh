#!/bin/bash
# =============================================================================
# download-dependencias-app.sh - instala o que o front precisa para rodar.
# Roda DENTRO do container "app", depois do setup-host.sh:
#
#   docker exec app bash /opt/citizentech/scripts/download-dependencias-app.sh
#
# O React depois do build é só HTML/JS/CSS: basta um servidor web (nginx).
# =============================================================================

LOG_FILE=/var/log/citizentech/dependencias-app.log

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOSTNAME] $1" | tee -a $LOG_FILE
}

erro() {
  log "ERRO: $1"
  log "===== FIM das dependências do front: FALHA ====="
  exit 1
}

log "===== INICIO das dependências do front ====="

[ -f /var/lib/citizentech/setup.ok ] || erro "rode o setup-host.sh antes"

log "Instalando nginx"
dnf install -y nginx >> $LOG_FILE 2>&1 || erro "falha ao instalar o nginx"
log "nginx instalado: $(nginx -v 2>&1)"

log "===== FIM das dependências do front: SUCESSO ====="
