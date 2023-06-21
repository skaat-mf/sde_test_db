#!/bin/bash
docker run \
   --name sde-pg \
   -e POSTGRES_PASSWORD="@sde_password012" \
   -e POSTGRES_USER="test_sde" \
   -e POSTGRES_DB="demo" \
   -p 5432:5432 \
   -v $(pwd)/sql/init_db:/docker-entrypoint-initdb.d \
   -v $(pwd)/sql:/$HOME/sql \
   -d postgres:15.3-alpine