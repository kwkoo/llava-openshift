FROM docker.io/bitnami/nginx:latest

COPY --chmod=664 ./html /html
COPY ./conf/server_block.conf /opt/bitnami/nginx/conf/server_blocks/server_block.conf

USER 0
RUN chmod g=u /html
USER 1001
