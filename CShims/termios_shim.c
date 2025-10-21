#include "termios_shim.h"
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>

static struct termios stk_orig;
static int stk_saved = 0;

int stk_enable_raw_mode(int fd) {
    struct termios t;
    if (tcgetattr(fd, &t) == -1) return -1;
    if (!stk_saved) {
        stk_orig = t;
        stk_saved = 1;
    }
    cfmakeraw(&t);
    t.c_oflag &= ~(OPOST);
    if (tcsetattr(fd, TCSANOW, &t) == -1) return -1;
    return 0;
}

int stk_restore_mode(int fd) {
    if (!stk_saved) return 0;
    return tcsetattr(fd, TCSANOW, &stk_orig);
}

int stk_get_winsize(int fd, int *cols, int *rows) {
    struct winsize ws;
    if (ioctl(fd, TIOCGWINSZ, &ws) == -1) return -1;
    if (cols) *cols = ws.ws_col;
    if (rows) *rows = ws.ws_row;
    return 0;
}

int stk_set_nonblocking(int fd, int enable) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) return -1;
    if (enable) flags |= O_NONBLOCK; else flags &= ~O_NONBLOCK;
    return fcntl(fd, F_SETFL, flags);
}
