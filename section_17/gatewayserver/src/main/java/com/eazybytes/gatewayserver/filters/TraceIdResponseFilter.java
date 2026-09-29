package com.eazybytes.gatewayserver.filters;

import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
public class TraceIdResponseFilter implements GlobalFilter {

    public static final String TRACE_ID_HEADER = "X-Trace-Id";

    private final Tracer tracer;

    public TraceIdResponseFilter(Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        exchange.getResponse().beforeCommit(() -> {
            Span currentSpan = tracer.currentSpan();
            if (currentSpan != null) {
                exchange.getResponse().getHeaders()
                        .add(TRACE_ID_HEADER, currentSpan.context().traceId());
            }
            return Mono.empty();
        });
        return chain.filter(exchange);
    }

}
