package io.makewebsite;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class MakeWebsiteApplication {
    public static void main(String[] args) {
        SpringApplication.run(MakeWebsiteApplication.class, args);
    }
}
