docker build -t tezos-volume .

# docker volume create my-vol

# docker run -it --entrypoint=sh -v my-vol:/rollup tezos-volume
# ./volume.exe /rollup/test.json

docker run -v my-vol:/rollup tezos-volume /rollup/vai.json
# docker run -v my-vol:/rollup tezos-volume /app/vai.json