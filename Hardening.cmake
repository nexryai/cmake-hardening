include(CheckCXXCompilerFlag)
include(FetchContent)

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "Clang is required for these hardening features.")
endif()

# These hardenings apply the following settings:
# - Build binaries with static linking using musl
# - Apply hardening to enhance memory security and integrity, such as stack protectors and CFI.
# 
# You can use CMakeFetchContent to enforce these rules.
#

# Using musl
set(MUSL_TARGET "x86_64-linux-musl")
add_compile_options(--target=${MUSL_TARGET})
add_link_options(--target=${MUSL_TARGET})

# --- Mimalloc Setup (Static & Secure) ---
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
    get_target_property(DISABLE_STATIC ${TARGET} HARDENING_DISABLE_STATIC)
    if(NOT DISABLE_STATIC)
        target_link_options(${TARGET} PRIVATE -static)
        target_link_options(${TARGET} PRIVATE -static-libgcc)
    endif()

    # 2.Stack Protector
    get_target_property(DISABLE_STACK ${TARGET} HARDENING_DISABLE_STACK)
    if(NOT DISABLE_STACK)
        target_compile_options(${TARGET} PRIVATE -fstack-protector-strong -fstack-clash-protection)
    endif()

    # 3. CFI & LTO
    get_target_property(DISABLE_CFI ${TARGET} HARDENING_DISABLE_CFI)
    if(NOT DISABLE_CFI)
        target_compile_options(${TARGET} PRIVATE -flto -fsanitize=cfi -fvisibility=hidden)
        target_link_options(${TARGET} PRIVATE -flto -fsanitize=cfi)
    endif()

    # 4. ASLR (PIE)
    get_target_property(DISABLE_ASLR ${TARGET} HARDENING_DISABLE_ASLR)
    if(NOT DISABLE_ASLR)
        set_target_properties(${TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
        target_link_options(${TARGET} PRIVATE -static-pie)
    endif()

    # 5. Mimalloc (Static Link)
    get_target_property(DISABLE_MIMALLOC ${TARGET} HARDENING_DISABLE_MIMALLOC)
    if(NOT DISABLE_MIMALLOC)
        target_link_libraries(${TARGET} PRIVATE mimalloc)
    endif()

    # 6. Linker Hardening
    get_target_property(DISABLE_LINKER ${TARGET} HARDENING_DISABLE_LINKER)
    if(NOT DISABLE_LINKER)
        target_link_options(${TARGET} PRIVATE -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack)
    endif()

    # Fortify & Format Security
    target_compile_definitions(${TARGET} PRIVATE _FORTIFY_SOURCE=3)
    target_compile_options(${TARGET} PRIVATE -Wformat -Wformat-security -Werror=format-security)
endfunction()