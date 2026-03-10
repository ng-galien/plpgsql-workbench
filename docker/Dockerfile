# pg-workbench — PostgreSQL 17 + PostGIS/SFCGAL + plpgsql_check + pgTAP
# Native ARM64 + AMD64 (multi-arch via postgres:17 base)

FROM postgres:17 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates postgresql-server-dev-17 perl \
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

FROM postgres:17

# PostGIS + SFCGAL (from official Debian packages, native ARM64)
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-17-postgis-3 \
    postgresql-17-postgis-3-scripts \
    libsfcgal2 \
    && rm -rf /var/lib/apt/lists/*

# plpgsql_check + pgTAP (from builder)
COPY --from=builder /usr/lib/postgresql/17/lib/ /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/ /usr/share/postgresql/17/extension/
