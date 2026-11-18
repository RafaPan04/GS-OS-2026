package br.com.fiap.colecity;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Regras do Colecity, com os dados em memória (MVP: reiniciou a API, volta aos
 * dados de exemplo).
 */
@Service
public class OcorrenciaService {

    private final Map<Long, Ocorrencia> ocorrencias = new LinkedHashMap<>();
    private final AtomicLong sequencia = new AtomicLong();

    /** Resultado de um relato: se virou ocorrência nova ou entrou numa existente. */
    public record ResultadoRelato(Ocorrencia ocorrencia, boolean somadoAExistente) {}

    public OcorrenciaService() {
        exemplo(Modulo.TRANSPORTE, "Ônibus não passa no horário", "6072/10 - Terminal Varginha",
                "À noite o intervalo passa de uma hora.", 37);
        exemplo(Modulo.TRANSPORTE, "Ônibus faz trajeto diferente do informado", "5106/10 - Jardim Selma",
                "Desvia pela avenida e não passa nos pontos da rua de cima.", 12);
        exemplo(Modulo.ENERGIA, "Falta de luz frequente", "Capão Redondo",
                "Quedas quase todo dia no fim da tarde.", 24);
        exemplo(Modulo.AGUA, "Falta de água à noite", "Brasilândia",
                "Torneira seca depois das 22h.", 9);
        exemplo(Modulo.VIAS, "Buraco grande na pista", "Estrada do M'Boi Mirim, 3000",
                "Está aí há meses, já estourou pneus.", 15);
    }

    public synchronized List<Ocorrencia> listar(Modulo modulo) {
        return ocorrencias.values().stream()
                .filter(o -> modulo == null || o.getModulo() == modulo)
                .sorted(Comparator.comparingInt(Ocorrencia::getPessoas).reversed())
                .toList();
    }

    public synchronized Optional<Ocorrencia> buscar(long id) {
        return Optional.ofNullable(ocorrencias.get(id));
    }

    /**
     * Registra um relato. Se o mesmo problema já existe, a pessoa entra no
     * abaixo-assinado dele em vez de criar um relato isolado.
     */
    public synchronized ResultadoRelato relatar(Modulo modulo, String titulo, String local,
                                                String descricao, String autor) {
        for (Ocorrencia o : ocorrencias.values()) {
            if (o.ehMesmoProblema(modulo, titulo, local)) {
                o.apoiar(autor);
                if (descricao != null && !descricao.isBlank()) {
                    o.comentar(autor, descricao);
                }
                return new ResultadoRelato(o, true);
            }
        }
        long id = sequencia.incrementAndGet();
        Ocorrencia nova = new Ocorrencia(id, modulo, titulo, local, descricao, autor);
        ocorrencias.put(id, nova);
        return new ResultadoRelato(nova, false);
    }

    public synchronized boolean apoiar(Ocorrencia o, String nome) {
        return o.apoiar(nome);
    }

    public synchronized void comentar(Ocorrencia o, String autor, String texto) {
        o.comentar(autor, texto);
    }

    /** Visão do gestor público: dimensão de cada módulo e onde agir primeiro. */
    public synchronized Map<String, Object> painel() {
        List<Map<String, Object>> porModulo = new ArrayList<>();
        for (Modulo m : Modulo.values()) {
            List<Ocorrencia> doModulo = listar(m);
            porModulo.add(Map.of(
                    "modulo", m,
                    "nome", m.getNome(),
                    "ocorrencias", doModulo.size(),
                    "pessoas", doModulo.stream().mapToInt(Ocorrencia::getPessoas).sum()));
        }
        List<Ocorrencia> todas = listar(null);
        return Map.of(
                "totalOcorrencias", todas.size(),
                "totalPessoas", todas.stream().mapToInt(Ocorrencia::getPessoas).sum(),
                "porModulo", porModulo,
                "ondeAgirPrimeiro", todas.stream().limit(3).toList());
    }

    private void exemplo(Modulo modulo, String titulo, String local, String descricao, int pessoas) {
        Ocorrencia o = relatar(modulo, titulo, local, descricao, "cidadao-1").ocorrencia();
        for (int i = 2; i <= pessoas; i++) {
            o.apoiar("cidadao-" + i);
        }
    }
}
