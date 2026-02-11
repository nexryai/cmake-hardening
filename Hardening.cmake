include(CheckCXXCompilerFlag)
include(FetchContent)
include(ExternalProject)

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "Clang is required for these hardening features.")
endif()

# These hardenings apply the following settings:
# - Build binaries with static linking using musl, without GNU
# - Apply hardening to enhance memory security and integrity, such as stack protectors and CFI.
# - Use mimalloc with MI_SECURE=4
#
# You can use CMakeFetchContent to enforce these rules.
#

# Build musl from source with hardening
set(MUSL_INSTALL_DIR "${CMAKE_BINARY_DIR}/musl_install")
set(MUSL_TARGET "x86_64-linux-musl")

ExternalProject_Add(musl_build
    GIT_REPOSITORY "https://git.musl-libc.org/git/musl"
    GIT_TAG "v1.2.5"
    CONFIGURE_COMMAND <SOURCE_DIR>/configure
        "CC=${CMAKE_C_COMPILER}"
        "AR=llvm-ar"
        "RANLIB=llvm-ranlib"
        --prefix=${MUSL_INSTALL_DIR}
        --target=${MUSL_TARGET}
        --disable-shared
    BUILD_COMMAND make CFLAGS=-fstack-protector-strong -j$(nproc)
    INSTALL_COMMAND make install
)

# Global Hardening Constants
set(HARDENING_COMMON_FLAGS
    "--target=${MUSL_TARGET}"
    "-flto=thin"
    "-fvisibility=hidden"
    "-fsanitize=cfi"
    "-isystem ${MUSL_INSTALL_DIR}/include"
)

set(HARDENING_C_FLAGS
    "${HARDENING_COMMON_FLAGS}"
    "-fstack-protector-strong"
    "-fstack-clash-protection"
    "-Wformat"
    "-Wformat-security"
    "-Werror=format-security"
    "-D_FORTIFY_SOURCE=3"
)
set(HARDENING_CXX_FLAGS "${HARDENING_C_FLAGS}")

set(HARDENING_LD_FLAGS
    "--target=${MUSL_TARGET}"
    "-fuse-ld=lld"
    "-stdlib=libc++"
    "-nostdlib++"
    "--rtlib=compiler-rt"
    "--unwindlib=libunwind"
    "-static"
    "-static-pie"
    "-L${MUSL_INSTALL_DIR}/lib"
    "-lc"
    "-lc++"
    "-lc++abi"
    "-lunwind"
    "-Wl,--allow-multiple-definition" # Resolve conflict between musl and mimalloc
    "-Wl,-z,relro"
    "-Wl,-z,now"
    "-Wl,-z,noexecstack"
)

add_compile_options("${HARDENING_C_FLAGS}")
add_link_options("${HARDENING_LD_FLAGS}")

string(REPLACE ";" " " HARDENING_C_FLAGS_STR "${HARDENING_C_FLAGS}")
string(REPLACE ";" " " HARDENING_LD_FLAGS_STR "${HARDENING_LD_FLAGS}")

# Mimalloc Setup
set(MI_SECURE "4" CACHE STRING "" FORCE)
set(MI_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MI_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(MI_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(MI_BUILD_OBJECT OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    mimalloc
    GIT_REPOSITORY https://github.com/microsoft/mimalloc
    GIT_TAG        main
)
FetchContent_MakeAvailable(mimalloc)

function(setup_target_hardening TARGET)
    add_dependencies(${TARGET} musl_build mimalloc-static)
    
    target_link_libraries(${TARGET} PRIVATE 
        mimalloc-static
    )
    
    set_target_properties(${TARGET} PROPERTIES 
        POSITION_INDEPENDENT_CODE ON
        INTERPROCEDURAL_OPTIMIZATION ON
    )
endfunction()