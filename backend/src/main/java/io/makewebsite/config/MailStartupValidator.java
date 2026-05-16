package io.makewebsite.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class MailStartupValidator implements ApplicationRunner {

    @Value("${spring.mail.host:}")
    private String host;

    @Value("${spring.mail.port:0}")
    private int port;

    @Value("${spring.mail.username:}")
    private String username;

    @Value("${spring.mail.password:}")
    private String password;

    @Override
    public void run(ApplicationArguments args) {
        if (password == null || password.isBlank() || password.contains("${")) {
            throw new IllegalStateException("GMAIL_APP_PASSWORD is not configured. Set it as a 16-character Gmail App Password without spaces.");
        }
        if (password.matches(".*\\s+.*")) {
            throw new IllegalStateException("GMAIL_APP_PASSWORD contains whitespace. Use the 16-character Gmail App Password without spaces.");
        }
        log.info("Mail configuration loaded: host={}, port={}, username={}, passwordLength={}",
                host, port, username, password.length());
    }
}
