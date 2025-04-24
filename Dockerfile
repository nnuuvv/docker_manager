ARG GLEAM_VERSION=v1.10.0

# Build stage - compile the application
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

# Add project code
COPY ./shared /build/shared
COPY ./client /build/client
COPY ./server /build/server

# Install dependencies for all projects
RUN cd /build/shared && gleam deps download
RUN cd /build/client && gleam deps download
RUN cd /build/server && gleam deps download

# Compile the client code and output to server's static directory
RUN cd /build/client \
  && gleam run -m lustre/dev build --minify --outdir=/build/server/priv/static

# Compile the server code
RUN cd /build/server \
  && gleam export erlang-shipment

# Runtime stage - slim image with only what's needed to run
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

# Install packages
RUN apk add curl

# Copy the compiled server code from the builder stage
COPY --from=builder /build/server/build/erlang-shipment /app

# Set up the entrypoint
WORKDIR /app
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV PORT=8080

# Expose the port the server will run on
EXPOSE 8080

# Run the server
CMD ["/app/entrypoint.sh", "run"]
