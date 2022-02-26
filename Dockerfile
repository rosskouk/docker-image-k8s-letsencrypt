FROM alpine:3.15.0
LABEL maintainer="Ross Stewart <rosskouk@gmail.com>"

RUN apk add certbot curl bash
RUN mkdir /root/http-root

COPY entrypoint.sh /root
COPY secret-patch-template.json /root

EXPOSE 80

CMD [ "/root/entrypoint.sh" ]