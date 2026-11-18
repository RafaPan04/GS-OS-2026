package br.com.fiap.colecity;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/** Verificação simples usada pelos scripts de deploy (mostra qual container respondeu). */
@RestController
public class StatusController {

    @Value("${app.message}")
    private String message;

    @Value("${CT_ENV:desconhecido}")
    private String environment;

    @GetMapping("/api/hello")
    public Map<String, Object> hello() throws Exception {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("message", message);
        body.put("host", InetAddress.getLocalHost().getHostName());
        body.put("environment", environment);
        body.put("timestamp", OffsetDateTime.now().toString());
        return body;
    }
}
