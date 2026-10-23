// Local-only test receiver for the CVE-2024-4536 DSP test (scripts/42_test_4536_dsp.sh).
// A single busybox `nc -l` loop handles one connection per iteration and drops any request
// that arrives in the gap between iterations — which lost the data-sink write (it arrives after
// the source GET / OAuth2 token POST), so the D7b positive control never fired. This replaces it
// with a concurrent HttpServer (JDK21 is already in the gradle build image; no new download).
//
// Behaviour: for EVERY request on any path it appends "<METHOD> <path>\n<body>\n===END===\n"
// to /cap.txt and replies 200 with a minimal OAuth2 token JSON, so: the HttpData source fetch
// (GET /data) gets a body to push, the OAuth2 sink token request (POST /token, carrying
// client_secret) completes, and the subsequent sink write (POST/PUT /sink) is captured too.
// It stores whatever bytes the connector sends — the test script greps /cap.txt and redacts the
// canary; nothing is persisted beyond the container's ephemeral /cap.txt.
import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.Executors;

public class Receiver {
  private static final Path CAP = Paths.get("/cap.txt");
  private static final byte[] TOKEN =
      "{\"access_token\":\"x\",\"token_type\":\"Bearer\",\"expires_in\":3600}".getBytes(StandardCharsets.UTF_8);

  public static void main(String[] args) throws Exception {
    HttpServer s = HttpServer.create(new InetSocketAddress(9300), 0);
    s.createContext("/", ex -> {
      byte[] body = ex.getRequestBody().readAllBytes();
      String rec = ex.getRequestMethod() + " " + ex.getRequestURI().getPath() + "\n"
                 + new String(body, StandardCharsets.UTF_8) + "\n===END===\n";
      synchronized (Receiver.class) {
        Files.write(CAP, rec.getBytes(StandardCharsets.UTF_8),
            StandardOpenOption.CREATE, StandardOpenOption.APPEND);
      }
      ex.getResponseHeaders().add("Content-Type", "application/json");
      ex.sendResponseHeaders(200, TOKEN.length);
      try (OutputStream os = ex.getResponseBody()) { os.write(TOKEN); }
    });
    s.setExecutor(Executors.newFixedThreadPool(8));
    s.start();
    System.out.println("receiver-ready");
  }
}
