FROM esydev/esy:nightly-alpine-latest as builder

RUN apk add libexecinfo-dev libexecinfo-static

WORKDIR /app

COPY ./esy.lock esy.json ./

RUN esy install
RUN esy build-dependencies --release

COPY . .

RUN esy build --release

RUN mv "_esy/default/build-release/default/src/volume/bin/main.exe" volume.exe
RUN strip ./volume.exe

FROM scratch as runtime
WORKDIR /app
COPY --from=builder /app/volume /app/volume

ENTRYPOINT ["/app/volume.exe"]
