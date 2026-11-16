FROM docker:latest

WORKDIR /usr/bin/APP

COPY --chmod=744 ./builder.sh .

ENTRYPOINT ["./builder.sh"]