FROM chimeralinux/chimera

RUN apk update && apk upgrade --no-cache && apk add --no-cache \
    clang cmake libcxx libcxxabi libunwind gcompat \
    shadow curl \
    git

RUN useradd -m -d /home/runner runner
