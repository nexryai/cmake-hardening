cmake_minimum_required(VERSION 3.24)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_AR "llvm-ar")
set(CMAKE_RANLIB "llvm-ranlib")

project(HardenedFFmpegTest LANGUAGES C CXX)

# Include the hardening configuration from the parent directory
include(../../Hardening.cmake)

include(ExternalProject)
set(FFMPEG_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/ffmpeg_install)

# Minimal FFmpeg: Disabling all codecs, parsers, and protocols
# Only essential libraries (avcodec, avformat, avutil) are enabled
ExternalProject_Add(ffmpeg_minimal
    URL https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
    CONFIGURE_COMMAND <SOURCE_DIR>/configure
        --prefix=${FFMPEG_INSTALL_DIR}
        --cc=clang
        --cxx=clang++
        --ld=clang
        --enable-static
        --disable-shared
        --disable-x86asm
        --disable-inline-asm
        --disable-doc
        --disable-all
        --enable-avcodec
        --enable-avformat
        --enable-avutil
        --extra-cflags=${HARDENING_C_FLAGS}
        --extra-ldflags=${HARDENING_LD_FLAGS}
    BUILD_BYPRODUCTS 
        ${FFMPEG_INSTALL_DIR}/lib/libavformat.a
        ${FFMPEG_INSTALL_DIR}/lib/libavcodec.a
        ${FFMPEG_INSTALL_DIR}/lib/libavutil.a
)

# Application to print FFmpeg version
add_executable(ffmpeg_version main.cpp)

target_compile_definitions(ffmpeg_version PRIVATE __STDC_CONSTANT_MACROS)

# Setup paths for the external library
target_include_directories(ffmpeg_version PRIVATE ${FFMPEG_INSTALL_DIR}/include)
target_link_libraries(ffmpeg_version PRIVATE 
    ${FFMPEG_INSTALL_DIR}/lib/libavformat.a
    ${FFMPEG_INSTALL_DIR}/lib/libavcodec.a
    ${FFMPEG_INSTALL_DIR}/lib/libavutil.a
)
add_dependencies(ffmpeg_version ffmpeg_minimal)

# Apply mandatory hardening (Static, Musl, Mimalloc, CFI)
setup_target_hardening(ffmpeg_version)