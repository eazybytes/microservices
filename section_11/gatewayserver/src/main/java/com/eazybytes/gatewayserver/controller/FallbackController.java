package com.eazybytes.gatewayserver.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

@RestController
public class FallbackController {

    private static final Logger logger = LoggerFactory.getLogger(FallbackController.class);

    @RequestMapping("/contactSupport")
    public Mono<String> contactSupport() {
        logger.warn("Circuit breaker fallback triggered, routing request to contactSupport");
        return Mono.just("An error occurred. Please try after some time or contact support team!!!");
    }
}
