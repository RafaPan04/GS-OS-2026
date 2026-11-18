package br.com.fiap.colecity;

import java.time.LocalDateTime;

public record Comentario(String autor, String texto, LocalDateTime criadoEm) {}
