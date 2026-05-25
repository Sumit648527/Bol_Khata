package com.bolkhata.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.HashMap;
import java.util.Map;

/**
 * Maps Render's DATABASE_URL to Spring datasource properties when
 * SPRING_DATASOURCE_URL is not already configured.
 */
public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        if (environment.getProperty("SPRING_DATASOURCE_URL") != null) {
            return;
        }

        String databaseUrl = environment.getProperty("DATABASE_URL");
        if (databaseUrl == null || databaseUrl.isBlank()) {
            return;
        }

        try {
            URI uri = new URI(databaseUrl.replace("postgres://", "postgresql://"));
            String[] userInfo = uri.getUserInfo().split(":", 2);

            Map<String, Object> properties = new HashMap<>();
            properties.put(
                "spring.datasource.url",
                String.format("jdbc:postgresql://%s:%d%s", uri.getHost(), uri.getPort(), uri.getPath())
            );
            properties.put("spring.datasource.username", userInfo[0]);
            properties.put("spring.datasource.password", userInfo.length > 1 ? userInfo[1] : "");

            environment.getPropertySources().addFirst(
                new MapPropertySource("renderDatabaseUrl", properties)
            );
        } catch (URISyntaxException e) {
            throw new IllegalStateException("Invalid DATABASE_URL format", e);
        }
    }
}
