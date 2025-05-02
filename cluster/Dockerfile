FROM ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine AS build
COPY . /app/
RUN cd /app && gleam export erlang-shipment

FROM erlang:alpine
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
