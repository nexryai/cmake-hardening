#include <stddef.h>
#include <string.h>

static inline void __fortify_panic(void) {
    __builtin_trap();
}

__attribute__((visibility("default")))
void *__memset_chk(void *dest, int c, size_t len, size_t destlen) {
    if (len > destlen) __fortify_panic();
    return memset(dest, c, len);
}

__attribute__((visibility("default")))
void *__memcpy_chk(void *dest, const void *src, size_t len, size_t destlen) {
    if (len > destlen) __fortify_panic();
    return memcpy(dest, src, len);
}

__attribute__((visibility("default")))
void *__memmove_chk(void *dest, const void *src, size_t len, size_t destlen) {
    if (len > destlen) __fortify_panic();
    return memmove(dest, src, len);
}

__attribute__((visibility("default")))
void *__mempcpy_chk(void *dest, const void *src, size_t len, size_t destlen) {
    if (len > destlen) __fortify_panic();
    return (char *)memcpy(dest, src, len) + len;
}