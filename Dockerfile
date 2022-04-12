FROM esydev/esy:nightly-alpine-latest as builder

WORKDIR /app

COPY esy.json ./
COPY ./esy.lock ./esy.lock
RUN esy install
RUN esy build-dependencies

COPY . .

RUN esy build --release

RUN mv "_esy/default/build-release/default/volume.exe" volume.exe
RUN strip ./volume.exe

FROM alpine as runtime
WORKDIR /app
COPY --from=builder /app/volume.exe /app/volume.exe

ENTRYPOINT ["/app/volume.exe"]
