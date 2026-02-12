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
        "CC=${CMAKE_C_COMPILER} --target=${MUSL_TARGET}"
        "AR=${CMAKE_AR}"
        "RANLIB=${CMAKE_RANLIB}"
        "CFLAGS=-fstack-protector-strong -flto=thin -fsplit-lto-unit"
        --prefix=${MUSL_INSTALL_DIR}
        --disable-shared
    BUILD_COMMAND make -j$(nproc)
    INSTALL_COMMAND make install
)

FetchContent_Declare(
    fortify_headers
    GIT_REPOSITORY https://github.com/jvoisin/fortify-headers.git
    GIT_TAG        3.0.1
)
FetchContent_MakeAvailable(fortify_headers)

set(FORTIFY_INCLUDE_DIR ${fortify_headers_SOURCE_DIR}/include)

# Global Hardening Constants
set(HARDENING_COMMON_FLAGS
    "--target=${MUSL_TARGET}"
    "-flto=thin"
    "-fsplit-lto-unit"
    "-fvisibility=hidden"
    "-fsanitize=cfi"
    "-isystem ${FORTIFY_INCLUDE_DIR}"
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

set(HARDENING_CXX_FLAGS
    "${HARDENING_C_FLAGS}"
    "-nostdinc++"
    "-isystem ${LLVM_RUNTIMES_INSTALL_DIR}/include/c++/v1"
)

# Build libc++, libc++abi, and libunwind for musl
set(LLVM_RUNTIMES_INSTALL_DIR "${CMAKE_BINARY_DIR}/llvm_runtimes_install")
set(LLVM_PROJECT_SOURCE "${CMAKE_BINARY_DIR}/llvm_runtimes-prefix/src/llvm_runtimes")

ExternalProject_Add(llvm_runtimes
    URL "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/llvm-project-18.1.8.src.tar.xz"
    SOURCE_SUBDIR "runtimes"
    DEPENDS musl_build
    LIST_SEPARATOR | 
    CMAKE_ARGS
        "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
        "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
        "-DCMAKE_INSTALL_PREFIX=${LLVM_RUNTIMES_INSTALL_DIR}"
        "-DLLVM_ENABLE_LTO=Thin"
        "-DLLVM_ENABLE_RUNTIMES=libcxx|libcxxabi|libunwind"
        "-DLIBCXX_CXX_ABI=libcxxabi"
        "-DLIBCXX_CXX_ABI_INCLUDE_PATHS=<SOURCE_DIR>/libcxxabi/include"
        "-DLIBCXX_HAS_MUSL_LIBC=ON"
        "-DLIBCXX_ENABLE_STATIC=ON"
        "-DLIBCXX_ENABLE_SHARED=OFF"
        "-DLIBCXXABI_USE_LLVM_UNWIND=ON"
        "-DLIBCXXABI_ENABLE_STATIC=ON"
        "-DLIBCXXABI_ENABLE_SHARED=OFF"
        "-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON"
        "-DLIBUNWIND_ENABLE_STATIC=ON"
        "-DLIBUNWIND_ENABLE_SHARED=OFF"
        "-DCMAKE_C_FLAGS=${HARDENING_C_FLAGS_STR} -fsplit-lto-unit --target=${MUSL_TARGET} -isystem ${MUSL_INSTALL_DIR}/include"
        "-DCMAKE_CXX_FLAGS=${HARDENING_CXX_FLAGS_STR} -fsplit-lto-unit --target=${MUSL_TARGET} -isystem ${MUSL_INSTALL_DIR}/include"
)

# Linker configs
set(HARDENING_LD_FLAGS_SUCKS
    "--target=${MUSL_TARGET}"
    "-fuse-ld=lld"
    "-static"
    "-static-pie"
    "-nostdlib++"
    "-Wl,-z,relro"
    "-Wl,-z,now"
    "-Wl,-z,noexecstack"
    "-Wl,--allow-multiple-definition"
)

set(HARDENING_LD_FLAGS
    "--target=${MUSL_TARGET}"
    "-fuse-ld=lld"
    "-stdlib=libc++"
    "-nostdlib++"
    "--rtlib=compiler-rt"
    "--unwindlib=libunwind"
    "-static"
    "-static-pie"
    "-L${LLVM_RUNTIMES_INSTALL_DIR}/lib"
    "-L${MUSL_INSTALL_DIR}/lib"
    # DO NOT USE THIS
    # -lcを追加するとmuslが使われない
    # 
    # "-lc"
    # "-lc++"
    # "-lc++abi"
    # "-lunwind"
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
    add_dependencies(${TARGET} musl_build llvm_runtimes mimalloc-static)
    
    target_include_directories(${TARGET} SYSTEM PRIVATE
        ${FORTIFY_INCLUDE_DIR}    
        ${LLVM_RUNTIMES_INSTALL_DIR}/include/c++/v1
        ${MUSL_INSTALL_DIR}/include
    )
    
    target_link_libraries(${TARGET} PRIVATE 
        mimalloc-static
        ${LLVM_RUNTIMES_INSTALL_DIR}/lib/libc++.a
        ${LLVM_RUNTIMES_INSTALL_DIR}/lib/libc++abi.a
        ${LLVM_RUNTIMES_INSTALL_DIR}/lib/libunwind.a
        ${MUSL_INSTALL_DIR}/lib/libc.a
    )
    
    set_target_properties(${TARGET} PROPERTIES 
        POSITION_INDEPENDENT_CODE ON
    )
endfunction()