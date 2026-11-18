#!/bin/bash
# =============================================================================
# download-dependencias-api.sh - instala o que a API precisa para rodar.
# Roda DENTRO do container "api", depois do setup-host.sh:
#
#
# Não precisa de servidor web: o Spring Boot já vem com o Tomcat embutido.
# =============================================================================

LOG_FILE=/var/log/citizentech/dependencias-api.log

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOSTNAME] $1" | tee -a $LOG_FILE
}

erro() {
  log "ERRO: $1"
  log "===== FIM das dependências da API: FALHA ====="
  exit 1
}

log "===== INICIO das dependências da API ====="

[ -f /var/lib/citizentech/setup.ok ] || erro "rode o setup-host.sh antes"

log "Instalando Java 21"
dnf install -y java-21-openjdk-headless >> $LOG_FILE 2>&1 || erro "falha ao instalar o Java"
log "Java instalado: $(java -version 2>&1 | head -1)"

log "===== FIM das dependências da API: SUCESSO ====="
