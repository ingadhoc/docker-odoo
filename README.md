# Docker Odoo

## IMPORTANTE

Una vez hecho el commit correspondiente, hay que triggerear la build de cada versión en adhoc/odoo/builds.

## Para hacer el build en local

MAXMIND_LICENSE_KEY se encuentra en el gestor de contraseñas

```sh
export DOCKER_BUILDKIT=1 \
    && docker build --no-cache \
    -t adhoc/odoo:17.0-dev \
    --build-arg MAXMIND_LICENSE_KEY= \
    -f 17.0.Dockerfile .
# docker push adhoc/odoo:17.0-dev
```
