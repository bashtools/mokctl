FROM docker:19
COPY mokctl.deploy /usr/bin/mokctl
RUN apk update \
    && apk upgrade \
    && apk add bash ncurses util-linux
ENTRYPOINT [ "/usr/bin/mokctl" ]
CMD [ "--help" ]
