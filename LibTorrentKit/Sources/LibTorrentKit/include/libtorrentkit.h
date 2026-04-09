#ifndef LIBTORRENTKIT_H
#define LIBTORRENTKIT_H

#ifdef __cplusplus
extern "C" {
#endif

// Opaque session handle
typedef struct lt_session_t lt_session_t;

// Session lifecycle
lt_session_t* lt_session_create(void);
void lt_session_destroy(lt_session_t* session);

#ifdef __cplusplus
}
#endif

#endif // LIBTORRENTKIT_H
