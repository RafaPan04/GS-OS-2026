#!/bin/bash
# teste-carga.sh - dispara muitas requisições ao app (localhost:8080) até a API
# estourar a memória e o systemd reiniciar o processo.
#
# Roda NA SUA MÁQUINA:   ./teste-carga.sh
#
# Como funciona:
#   - cada requisição registra uma ocorrência com um texto grande (200 KB);
#   - a API guarda tudo em memória, então o uso de memória só cresce;
#   - ao passar de 256 MB (-Xmx256m), a JVM encerra (-XX:+ExitOnOutOfMemoryError);
#   - o systemd percebe que o processo morreu e reinicia (Restart=always).
#
# O caminho da requisição é: sua máquina -> app (nginx) -> api (Spring Boot)

URL=http://localhost:8080/api/ocorrencias
PARALELO=100          # requisições disparadas ao mesmo tempo
TAMANHO_KB=500       # tamanho do texto de cada ocorrência
MAX_REQUISICOES=5000 # trava de segurança: para o teste se nada acontecer

log() {
  echo "$(date '+%H:%M:%S') [teste-carga] $1"
}

# Lê do systemd do container "api" quantas vezes a API já foi reiniciada
reinicios() {
  docker exec api systemctl show citizentech-api -p NRestarts --value
}

pid_api() {
  docker exec api systemctl show citizentech-api -p MainPID --value
}

curl -s http://localhost:8080/api/hello | grep -q message \
  || { log "ERRO: a API não está respondendo em http://localhost:8080/api/hello"; exit 1; }

ANTES=$(reinicios)
log "API rodando com PID $(pid_api). Reinícios até agora: $ANTES"
log "Limites do serviço: $(docker exec api systemctl show citizentech-api -p MemoryMax -p CPUQuotaPerSecUSec | tr '\n' ' ')"
log "Enviando $PARALELO requisições por vez, cada uma com ${TAMANHO_KB} KB..."

# Texto grande, repetido em todas as requisições
TEXTO=$(head -c $((TAMANHO_KB * 1024)) /dev/zero | tr '\0' 'x')

ENVIADAS=0
while [ $ENVIADAS -lt $MAX_REQUISICOES ]; do

  # dispara um lote de requisições em paralelo (o & coloca cada curl em segundo plano)
  for _ in $(seq 1 $PARALELO); do      # repete PARALELO vezes
    ENVIADAS=$((ENVIADAS + 1))
    printf '{"modulo":"VIAS","titulo":"Teste de carga %s","local":"Laboratorio","descricao":"%s","autor":"teste-carga"}' \
      "$ENVIADAS" "$TEXTO" \
      | curl -s -o /dev/null --max-time 15 -H 'Content-Type: application/json' -d @- $URL &
  done
  wait   # espera o lote terminar

  AGORA=$(reinicios)
  log "$ENVIADAS requisições enviadas | memória da API: $(docker exec api systemctl show citizentech-api -p MemoryCurrent --value) bytes | reinícios: $AGORA"

  if [ "$AGORA" -gt "$ANTES" ]; then
    break
  fi
done

if [ "$AGORA" -le "$ANTES" ]; then
  log "A API aguentou $MAX_REQUISICOES requisições sem reiniciar. Fim do teste."
  exit 1
fi

echo
log "A API estourou a memória e o systemd REINICIOU o processo!"
echo
log "Histórico do systemd:"
docker exec api journalctl -u citizentech-api -n 8 --no-pager
echo
log "Erro registrado no log da API:"
docker exec api grep -i "OutOfMemoryError" /var/log/citizentech/api.log | tail -2
echo

log "Aguardando a API voltar..."
until curl -s http://localhost:8080/api/hello | grep -q message; do
  sleep 2
done
log "API de volta com novo PID $(pid_api). Reinícios: $(reinicios)"
