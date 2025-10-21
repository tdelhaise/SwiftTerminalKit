#ifndef TERMIOS_SHIM_H
#define TERMIOS_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int stk_enable_raw_mode(int fd);
int stk_restore_mode(int fd);
int stk_get_winsize(int fd, int *cols, int *rows);
int stk_set_nonblocking(int fd, int enable);

#ifdef __cplusplus
}
#endif

#endif
