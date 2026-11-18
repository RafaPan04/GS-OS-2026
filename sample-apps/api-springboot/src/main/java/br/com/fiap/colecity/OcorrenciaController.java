package br.com.fiap.colecity;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * API pública do Colecity: cidadãos relatam e apoiam; o poder público consulta.
 *
 *   GET  /api/modulos                        módulos disponíveis
 *   GET  /api/ocorrencias?modulo=TRANSPORTE  ocorrências, da que mais afeta pessoas para a que menos afeta
 *   GET  /api/ocorrencias/{id}               detalhe com comentários
 *   POST /api/ocorrencias                    relatar (se já existir, soma ao abaixo-assinado)
 *   POST /api/ocorrencias/{id}/apoios        "eu também"
 *   POST /api/ocorrencias/{id}/comentarios   comentar
 *   GET  /api/painel                         dimensão por módulo e onde agir primeiro
 */
@RestController
@RequestMapping("/api")
public class OcorrenciaController {

    private final OcorrenciaService service;

    public OcorrenciaController(OcorrenciaService service) {
        this.service = service;
    }

    public record NovoRelato(Modulo modulo, String titulo, String local, String descricao, String autor) {}
    public record Apoio(String nome) {}
    public record NovoComentario(String autor, String texto) {}

    @GetMapping("/modulos")
    public List<Map<String, Object>> modulos() {
        return Arrays.stream(Modulo.values())
                .map(m -> Map.<String, Object>of("id", m, "nome", m.getNome(), "rotuloLocal", m.getRotuloLocal()))
                .toList();
    }

    @GetMapping("/ocorrencias")
    public List<Ocorrencia> listar(@RequestParam(required = false) Modulo modulo) {
        return service.listar(modulo);
    }

    @GetMapping("/ocorrencias/{id}")
    public Ocorrencia detalhe(@PathVariable long id) {
        return buscar(id);
    }

    @PostMapping("/ocorrencias")
    public ResponseEntity<Map<String, Object>> relatar(@RequestBody NovoRelato r) {
        if (r.modulo() == null) throw erro("informe o módulo");
        exigir(r.titulo(), "título");
        exigir(r.local(), "local");
        exigir(r.autor(), "seu nome");

        var resultado = service.relatar(r.modulo(), r.titulo().trim(), r.local().trim(), r.descricao(), r.autor().trim());
        String mensagem = resultado.somadoAExistente()
                ? "Outras pessoas já relataram este problema. Seu relato foi somado ao abaixo-assinado."
                : "Ocorrência registrada. Compartilhe para outras pessoas apoiarem.";
        return ResponseEntity
                .status(resultado.somadoAExistente() ? HttpStatus.OK : HttpStatus.CREATED)
                .body(Map.of("mensagem", mensagem, "ocorrencia", resultado.ocorrencia()));
    }

    @PostMapping("/ocorrencias/{id}/apoios")
    public Map<String, Object> apoiar(@PathVariable long id, @RequestBody Apoio a) {
        exigir(a.nome(), "seu nome");
        Ocorrencia o = buscar(id);
        boolean novo = service.apoiar(o, a.nome());
        return Map.of(
                "mensagem", novo ? "Você entrou no abaixo-assinado." : "Você já apoia esta ocorrência.",
                "pessoas", o.getPessoas());
    }

    @PostMapping("/ocorrencias/{id}/comentarios")
    @ResponseStatus(HttpStatus.CREATED)
    public Ocorrencia comentar(@PathVariable long id, @RequestBody NovoComentario c) {
        exigir(c.autor(), "seu nome");
        exigir(c.texto(), "comentário");
        Ocorrencia o = buscar(id);
        service.comentar(o, c.autor().trim(), c.texto().trim());
        return o;
    }

    @GetMapping("/painel")
    public Map<String, Object> painel() {
        return service.painel();
    }

    private Ocorrencia buscar(long id) {
        return service.buscar(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "ocorrência não encontrada"));
    }

    private static void exigir(String valor, String campo) {
        if (valor == null || valor.isBlank()) throw erro("informe " + campo);
    }

    private static ResponseStatusException erro(String mensagem) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, mensagem);
    }
}
