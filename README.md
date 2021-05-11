# PgBouncer docker

![GitHub last commit](https://img.shields.io/github/last-commit/WoozyMasta/pgbouncer?style=flat-square)

```bash
docker pull woozymasta/pgbouncer:latest-cares
docker pull woozymasta/pgbouncer:latest-udns
```

[DockerHub](https://hub.docker.com/r/woozymasta/pgbouncer)

![Docker Pulls](https://img.shields.io/docker/pulls/woozymasta/pgbouncer?style=flat-square)
![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/woozymasta/pgbouncer?sort=semver&style=flat-square)

```bash
docker pull woozymasta/pgbouncer-exporter:latest
```

[DockerHub](https://hub.docker.com/r/woozymasta/pgbouncer-exporter)

![Docker Pulls](https://img.shields.io/docker/pulls/woozymasta/pgbouncer-exporter?style=flat-square)
![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/woozymasta/pgbouncer-exporter?sort=semver&style=flat-square)


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
