FROM alpine:3.15.0
LABEL maintainer="Ross Stewart <rosskouk@gmail.com>"

RUN apk add certbot curl bash
RUN mkdir /root/http-root

COPY create-secret.sh /root
COPY create-cron-job.sh /root
COPY tpl-secret.json /root
COPY tpl-cron-job.json /root

RUN chmod 755 /root/*.sh

EXPOSE 80

CMD [ "/root/entrypoint.sh" ]