package br.com.fiap.colecity;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Um problema urbano relatado. Cada pessoa que relata o mesmo problema ou
 * clica em "eu também" entra no abaixo-assinado (apoiadores).
 */
public class Ocorrencia {

    private final long id;
    private final Modulo modulo;
    private final String titulo;
    private final String local;
    private final String descricao;
    private final LocalDateTime criadaEm;
    private final Set<String> apoiadores = new LinkedHashSet<>();
    private final List<Comentario> comentarios = new ArrayList<>();

    public Ocorrencia(long id, Modulo modulo, String titulo, String local, String descricao, String autor) {
        this.id = id;
        this.modulo = modulo;
        this.titulo = titulo;
        this.local = local;
        this.descricao = descricao;
        this.criadaEm = LocalDateTime.now();
        this.apoiadores.add(autor.trim().toLowerCase());
    }

    /** Mesmo módulo, mesmo local e mesmo título = mesmo problema. */
    public boolean ehMesmoProblema(Modulo modulo, String titulo, String local) {
        return this.modulo == modulo
                && normalizar(this.titulo).equals(normalizar(titulo))
                && normalizar(this.local).equals(normalizar(local));
    }

    /** Retorna false se a pessoa já tinha apoiado. */
    public boolean apoiar(String nome) {
        return apoiadores.add(nome.trim().toLowerCase());
    }

    public void comentar(String autor, String texto) {
        comentarios.add(new Comentario(autor, texto, LocalDateTime.now()));
    }

    private static String normalizar(String s) {
        return s == null ? "" : s.trim().toLowerCase();
    }

    public long getId() { return id; }
    public Modulo getModulo() { return modulo; }
    public String getTitulo() { return titulo; }
    public String getLocal() { return local; }
    public String getDescricao() { return descricao; }
    public LocalDateTime getCriadaEm() { return criadaEm; }
    public List<Comentario> getComentarios() { return comentarios; }

    /** Indicador principal: pessoas afetadas por esta ocorrência. */
    public int getPessoas() { return apoiadores.size(); }

    @JsonIgnore
    public Set<String> getApoiadores() { return apoiadores; }
}
