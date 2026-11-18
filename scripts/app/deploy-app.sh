#!/bin/bash
# =============================================================================
# deploy-app.sh - publica o front React e inicia o nginx no container "app".
# Roda DENTRO do container, depois do download-dependencias-app.sh:
#
# O build (pasta dist) é colocado em /opt/citizentech/dist pelo add-arquivos-app.sh.
# O nginx entrega o React e repassa as chamadas /api/ para o container "api".
# =============================================================================

LOG_FILE=/var/log/citizentech/deploy-app.log
DIST_RECEBIDO=/opt/citizentech/dist     # onde o add-arquivos-app.sh colocou o build
SITE_DIR=/opt/citizentech/www           # pasta servida pelo nginx

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOSTNAME] $1" | tee -a $LOG_FILE
}

erro() {
  log "ERRO: $1"
  log "===== FIM do deploy do front: FALHA ====="
  exit 1
}

log "===== INICIO do deploy do front ====="

# 1. Pré-requisitos
[ -f /var/lib/citizentech/setup.ok ] || erro "rode o setup-host.sh antes"
command -v nginx > /dev/null || erro "nginx não instalado: rode o download-dependencias-app.sh antes"
[ -f $DIST_RECEBIDO/index.html ] || erro "build não encontrado em $DIST_RECEBIDO (rode o add-arquivos-app.sh)"

# 2. Arquivos do site e permissões do nginx atende com o usuário "nginx": ele só precisa LER os arquivos
rm -rf $SITE_DIR
cp -r $DIST_RECEBIDO $SITE_DIR || erro "falha ao copiar o build"
chown -R root:root $SITE_DIR
chmod -R 755 $SITE_DIR
log "Front publicado em $SITE_DIR"

# 3. Configuração do nginx (substitui a padrão pela do projeto em /config/nginx.conf)
cp /opt/citizentech/config/nginx.conf /etc/nginx/nginx.conf || erro "nginx.conf não encontrado"
nginx -t >> $LOG_FILE 2>&1 || erro "configuração do nginx inválida (veja $LOG_FILE)"
log "Configuração do nginx válida"

# 4. Serviço systemd do projeto no lugar do nginx.service do pacote(o custimizado determina limite de memoria e CPU)
systemctl disable --now nginx.service >> $LOG_FILE 2>&1
cp /opt/citizentech/systemd/citizentech-app.service /etc/systemd/system/ || erro "citizentech-app.service não encontrado"
systemctl daemon-reload
systemctl enable citizentech-app.service >> $LOG_FILE 2>&1 || erro "falha ao habilitar o serviço"
systemctl restart citizentech-app.service || erro "falha ao iniciar o serviço (veja journalctl -u citizentech-app)"
log "Serviço citizentech-app iniciado"
log "Limites: $(systemctl show citizentech-app -p MemoryMax -p CPUQuotaPerSecUSec | tr '\n' ' ')"

# 5. Teste
sleep 2
curl -s http://localhost/ | grep -q 'id="root"' || erro "front não respondeu em http://localhost/"
log "Front respondendo em http://localhost/ (na sua máquina: http://localhost:8080)"

if curl -s http://localhost/api/hello | grep -q message; then
  log "Proxy /api OK: front conversa com a API"
else
  log "AVISO: /api não respondeu (a API já foi implantada?)"
fi

log "===== FIM do deploy do front: SUCESSO ====="
