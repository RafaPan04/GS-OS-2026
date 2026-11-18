#!/bin/bash
# =============================================================================
# monitor.sh - verifica CPU, memória e disco a cada 30 segundos.
#
# É executado pelo systemd (monitor.service) com o usuário "monitor".
# Tudo que o script imprime com echo vai para /var/log/citizentech/monitor.log
# (quem direciona é o próprio systemd, ver StandardOutput no .service).
# Alertas também são gravados em /var/log/citizentech/alerts.log
# =============================================================================

CPU_LIMITE=80       # %
MEM_LIMITE=80       # %
DISCO_LIMITE=85     # %
INTERVALO=30        # segundos
ALERTAS=/var/log/citizentech/alerts.log

agora() {
  date '+%Y-%m-%d %H:%M:%S'
}

alerta() {
  echo "$(agora) [$HOSTNAME] ALERTA: $1"
  echo "$(agora) [$HOSTNAME] ALERTA: $1" >> $ALERTAS
}

# Quando o systemd pede para parar (systemctl stop), registra e sai
trap 'echo "$(agora) [$HOSTNAME] Monitor parado (PID $$)"; exit 0' TERM

echo "$(agora) [$HOSTNAME] Monitor iniciado (PID $$)"

while true; do

  # CPU: o vmstat mostra o % de CPU ociosa na coluna 15 ("id").
  #      Uso = 100 - ociosa. "vmstat 1 2" mede durante 1 segundo.
  CPU=$(vmstat 1 2 | tail -1 | awk '{print 100 - $15}')

  # Memória: na linha "Mem:" do free, coluna 2 = total e coluna 7 = disponível.
  #          Uso = (total - disponível) * 100 / total
  MEM=$(free | grep Mem | awk '{print int(($2 - $7) * 100 / $2)}')

  # Disco: o df mostra o % usado na coluna 5 (ex: 42%). O tr tira o "%".
  DISCO=$(df / | tail -1 | awk '{print $5}' | tr -d '%')

  # Se alguma coleta falhou, registra o erro e sai.
  # O systemd percebe a saída e reinicia o serviço (Restart=always).
  if [ -z "$CPU" ] || [ -z "$MEM" ] || [ -z "$DISCO" ]; then
    echo "$(agora) [$HOSTNAME] ERRO: falha ao coletar métricas"
    exit 1
  fi

  echo "$(agora) [$HOSTNAME] CPU=${CPU}% MEM=${MEM}% DISCO=${DISCO}%"

  if [ "$CPU" -ge "$CPU_LIMITE" ]; then
    alerta "CPU em ${CPU}% (limite ${CPU_LIMITE}%)"
  fi

  if [ "$MEM" -ge "$MEM_LIMITE" ]; then
    alerta "Memória em ${MEM}% (limite ${MEM_LIMITE}%)"
  fi

  if [ "$DISCO" -ge "$DISCO_LIMITE" ]; then
    alerta "Disco em ${DISCO}% (limite ${DISCO_LIMITE}%)"
  fi

  sleep $INTERVALO
done
