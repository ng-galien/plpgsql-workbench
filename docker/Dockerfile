FROM postgres:17-alpine AS builder

RUN apk add --no-cache build-base git postgresql-dev perl

# plpgsql_check
RUN git clone --depth 1 https://github.com/okbob/plpgsql_check.git /tmp/plpgsql_check \
    && cd /tmp/plpgsql_check \
    && make USE_PGXS=1 with_llvm=no \
    && make USE_PGXS=1 with_llvm=no install

# pgTAP
RUN git clone --depth 1 https://github.com/theory/pgtap.git /tmp/pgtap \
    && cd /tmp/pgtap \
    && make \
    && make install

FROM postgres:17-alpine

COPY --from=builder /usr/local/lib/postgresql/ /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/extension/ /usr/local/share/postgresql/extension/
