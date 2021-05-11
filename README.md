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
  -e POSTGRES_HOST=10.100.100.163 \
  -e POSTGRES_PASSWORD=QtdhslqWctiC2KGfn2pT \
  pgbouncer-exporter \

```

```sql
CREATE ROLE pgbouncer WITH LOGIN SUPERUSER PASSWORD 'pgbouncer-password';
CREATE DATABASE pgbouncer WITH OWNER pgbouncer;
```

```bash
kubectl create secret generic pgbouncer \
  --from-literal="POSTGRES_PASSWORD=pgbouncer-password"

kubectl apply -f deploy.yaml
```

* [Grafana Dashboard](https://grafana.com/grafana/dashboards/10945) - `10945`
* [Grafana Dashboard](https://grafana.com/grafana/dashboards/13353) - `13353`
