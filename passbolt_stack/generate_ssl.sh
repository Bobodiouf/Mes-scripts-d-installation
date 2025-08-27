#!/bin/bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/private.key \
    -out ssl/certificate.crt \
    -subj "/C=FR/ST=Dakar/L=Dakar/O=SOGEST/CN=passbolt.local"