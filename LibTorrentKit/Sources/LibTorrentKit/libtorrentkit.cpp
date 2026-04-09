#include "libtorrentkit.h"

// Stub implementation — will be filled once libtorrent is compiled
struct lt_session_t {
    // placeholder
};

lt_session_t* lt_session_create(void) {
    return new lt_session_t();
}

void lt_session_destroy(lt_session_t* session) {
    delete session;
}
