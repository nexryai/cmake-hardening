FROM chimeralinux/chimera

RUN apk update && apk add --no-cache \
    clang cmake libcxx libcxxabi libunwind \
    curl \
    git

RUN adduser -D runner
