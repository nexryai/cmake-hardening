include(CheckCXXCompilerFlag)
include(FetchContent)

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

# Global Hardening Constants
set(MUSL_TARGET "x86_64-linux-musl")
set(HARDENING_COMMON_FLAGS "--target=${MUSL_TARGET} --rtlib=compiler-rt --unwindlib=libunwind -flto")

set(HARDENING_C_FLAGS "${HARDENING_COMMON_FLAGS} -fstack-protector-strong -fstack-clash-protection -fvisibility=hidden -Wformat -Wformat-security -Werror=format-security -D_FORTIFY_SOURCE=3")
set(HARDENING_CXX_FLAGS "${HARDENING_C_FLAGS}")

# Linker flags including static runtime enforcement
set(HARDENING_LD_FLAGS "${HARDENING_COMMON_FLAGS} -static -static-libgcc -static-pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack")

# Apply globally to the current CMake project
add_compile_options(${HARDENING_C_FLAGS})
add_link_options(${HARDENING_LD_FLAGS})

# Mimalloc Setup
set(MI_SECURE "4" CACHE STRING "" FORCE)
set(MI_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MI_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(MI_BUILD_OBJECT ON CACHE BOOL "" FORCE)

FetchContent_Declare(
    mimalloc
    GIT_REPOSITORY https://github.com/microsoft/mimalloc
    GIT_TAG        main
)
FetchContent_MakeAvailable(mimalloc)

function(setup_target_hardening TARGET)
    # Mandatory linking
    target_link_libraries(${TARGET} PRIVATE mimalloc)

    # Mandatory CFI
    target_compile_options(${TARGET} PRIVATE -fsanitize=cfi)
    target_link_options(${TARGET} PRIVATE -fsanitize=cfi)

    set_target_properties(${TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
endfunction()