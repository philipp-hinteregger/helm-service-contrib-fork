# Use the offical Golang image to create a build artifact.
# This is based on Debian and sets the GOPATH to /go.
# https://hub.docker.com/_/golang
FROM golang:1.12 as builder
ARG version=develop

WORKDIR /go/src/github.com/keptn/keptn/helm-service

# Force the go compiler to use modules 
ENV GO111MODULE=on
ENV BUILDFLAGS=""
ENV GOPROXY=https://proxy.golang.org

# Copy `go.mod` for definitions and `go.sum` to invalidate the next layer
# in case of a change in the dependencies
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

ARG debugBuild

# set buildflags for debug build
RUN if [ ! -z "$debugBuild" ]; then export BUILDFLAGS='-gcflags "all=-N -l"'; fi

# Copy local code to the container image. 
COPY . .

# Build the command inside the container.
# (You may fetch or manage dependencies here, either manually or with a tool like "godep".)
RUN CGO_ENABLED=0 GOOS=linux go build $BUILDFLAGS -v -o helm-service

# Use a Docker multi-stage build to create a lean production image.
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM alpine:3.7
RUN apk add --no-cache ca-certificates

ARG HELM_VERSION=2.12.3
RUN wget https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz && \
  tar -zxvf helm-v$HELM_VERSION-linux-amd64.tar.gz && \
  mv linux-amd64/helm /bin/helm && \
  rm -rf linux-amd64 && rm -rf helm-v$HELM_VERSION-linux-amd64.tar.gz

ARG debugBuild

# IF we are debugging, we need to install libc6-compat for delve to work on alpine based containers
RUN if [ ! -z "$debugBuild" ]; then apk add --no-cache libc6-compat; fi

# Copy the binary to the production image from the builder stage.
COPY --from=builder /go/src/github.com/keptn/keptn/helm-service/helm-service /helm-service

EXPOSE 8080

# required for external tools to detect this as a go binary
ENV GOTRACEBACK=all

# KEEP THE FOLLOWING LINES COMMENTED OUT!!! (they will be included within the travis-ci build)
#travis-uncomment ADD MANIFEST /
#travis-uncomment COPY entrypoint.sh /
#travis-uncomment ENTRYPOINT ["/entrypoint.sh"]

# Run the web service on container startup.
CMD ["/helm-service"]