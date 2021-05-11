# PgBouncer docker

Run pgbouncer:

```bash
docker run --rm -ti \
  -p 5432:5432
  -e POSTGRES_HOST=10.100.100.163 \
  -e POSTGRES_PASSWORD=QtdhslqWctiC2KGfn2pT \
  woozymasta/pgbouncer:1.15.0-cares
```

Run pgbouncer-exporter:

```bash
podman run --rm -ti \
  -p 9127:9127 \
  pgbouncer-exporter \
  --pgBouncer.connectionString="postgres://postgres:QtdhslqWctiC2KGfn2pT@192.168.100.251:5432/pgbouncer?sslmode=disable" \
  --web.listen-address=":9127"
```

* [Grafana Dashboard](https://grafana.com/grafana/dashboards/9760) - `9760`
* [Grafana Dashboard](https://grafana.com/grafana/dashboards/13353) - `13353`
