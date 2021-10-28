FROM alpine

RUN apk add tshark jq

COPY ./collect_script.sh /collect_script.sh

ENTRYPOINT ["bash", "-c", "./collect_script.sh"]
