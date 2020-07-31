FROM rust:1.45-alpine

RUN apk add bash

WORKDIR /usr/src/densers
COPY . .

RUN cargo install --path .

CMD ["densers"]
