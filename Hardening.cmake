include(CheckCXXCompilerFlag)
include(FetchContent)

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "Clang is required for these hardening features.")
endif()

# --- Mimalloc Setup (Global) ---
set(MI_SECURE "4" CACHE STRING "" FORCE)
set(MI_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MI_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(MI_BUILD_OBJECT OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    mimalloc
    GIT_REPOSITORY https://github.com/microsoft/mimalloc
    GIT_TAG        main
)
FetchContent_MakeAvailable(mimalloc)

function(setup_target_hardening TARGET)
    # 1. Stack Protector & Clash Protection
    get_target_property(DISABLE_STACK ${TARGET} HARDENING_DISABLE_STACK)
    if(NOT DISABLE_STACK)
        target_compile_options(${TARGET} PRIVATE -fstack-protector-strong -fstack-clash-protection)
    endif()

    # 2. Control Flow Integrity (CFI) & LTO
    get_target_property(DISABLE_CFI ${TARGET} HARDENING_DISABLE_CFI)
    if(NOT DISABLE_CFI)
        target_compile_options(${TARGET} PRIVATE -flto -fsanitize=cfi -fvisibility=hidden)
        target_link_options(${TARGET} PRIVATE -flto -fsanitize=cfi)
    endif()

    # 3. PIE/PIC
    get_target_property(DISABLE_ASLR ${TARGET} HARDENING_DISABLE_ASLR)
    if(NOT DISABLE_ASLR)
        set_target_properties(${TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
        target_link_options(${TARGET} PRIVATE -pie)
    endif()

    # 4. Mimalloc
    get_target_property(DISABLE_MIMALLOC ${TARGET} HARDENING_DISABLE_MIMALLOC)
    if(NOT DISABLE_MIMALLOC)
        target_link_libraries(${TARGET} PRIVATE mimalloc)
    endif()

    # 5. Read-Only Relocations (RELRO) & Stack Execution Prevention
    get_target_property(DISABLE_LINKER_HARDENING ${TARGET} HARDENING_DISABLE_LINKER)
    if(NOT DISABLE_LINKER_HARDENING)
        target_link_options(${TARGET} PRIVATE -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack)
    endif()

    # 6. Fortify Source & Format Security
    target_compile_definitions(${TARGET} PRIVATE _FORTIFY_SOURCE=3)
    target_compile_options(${TARGET} PRIVATE -Wformat -Wformat-security -Werror=format-security)
endfunction()