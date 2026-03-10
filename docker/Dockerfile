FROM postgis/postgis:17-3.5 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git postgresql-server-dev-17 perl \
    && rm -rf /var/lib/apt/lists/*

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

FROM postgis/postgis:17-3.5

COPY --from=builder /usr/lib/postgresql/17/lib/ /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/ /usr/share/postgresql/17/extension/
