package br.com.fiap.colecity;

/** Módulos temáticos do Colecity. Transporte é o MVP; os demais são expansão. */
public enum Modulo {
    TRANSPORTE("Transporte público", "Linha"),
    ENERGIA("Energia", "Bairro / região"),
    AGUA("Água", "Bairro / região"),
    VIAS("Vias", "Rua / endereço");

    private final String nome;
    private final String rotuloLocal;

    Modulo(String nome, String rotuloLocal) {
        this.nome = nome;
        this.rotuloLocal = rotuloLocal;
    }

    public String getNome() { return nome; }
    public String getRotuloLocal() { return rotuloLocal; }
}
