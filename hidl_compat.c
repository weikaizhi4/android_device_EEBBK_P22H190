#include <stdbool.h>
void eebbk_hidl_error_write_log(int tag, const char *subtag)
    __asm__("_ZN7android8hardware7details13errorWriteLogEiPKc");
void eebbk_hidl_error_write_log(int tag, const char *subtag) {
    (void)tag;
    (void)subtag;
}
bool eebbk_hidl_check(bool condition, const char *message)
    __asm__("_ZN7android8hardware7details5checkEbPKc");
bool eebbk_hidl_check(bool condition, const char *message) {
    (void)message;
    return condition;
}
void eebbk_hidl_log_error(const void *message)
    __asm__("_ZN7android8hardware7details8logErrorERKNSt3__112basic_stringIcNS2_11char_traitsIcEENS2_9allocatorIcEEEE");
void eebbk_hidl_log_error(const void *message) {
    (void)message;
}
