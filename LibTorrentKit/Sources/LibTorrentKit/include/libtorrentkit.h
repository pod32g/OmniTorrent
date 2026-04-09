#ifndef LIBTORRENTKIT_H
#define LIBTORRENTKIT_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lt_session_t lt_session_t;
typedef struct lt_torrent_t lt_torrent_t;

lt_session_t* lt_session_create(int listen_port);
void lt_session_destroy(lt_session_t* session);
void lt_session_set_download_limit(lt_session_t* session, int bytes_per_sec);
void lt_session_set_upload_limit(lt_session_t* session, int bytes_per_sec);

lt_torrent_t* lt_add_torrent_magnet(lt_session_t* session, const char* magnet_uri, const char* save_path);
lt_torrent_t* lt_add_torrent_file(lt_session_t* session, const char* torrent_path, const char* save_path);
lt_torrent_t* lt_add_torrent_resume(lt_session_t* session, const void* resume_data, int resume_data_len, const char* save_path);

void lt_torrent_pause(lt_torrent_t* torrent);
void lt_torrent_resume(lt_torrent_t* torrent);
void lt_torrent_remove(lt_session_t* session, lt_torrent_t* torrent, bool delete_files);
void lt_torrent_set_sequential(lt_torrent_t* torrent, bool sequential);
void lt_torrent_set_download_limit(lt_torrent_t* torrent, int bytes_per_sec);
void lt_torrent_set_upload_limit(lt_torrent_t* torrent, int bytes_per_sec);

typedef struct {
    int state;
    float progress;
    int64_t total_size;
    int64_t total_done;
    int download_rate;
    int upload_rate;
    int num_peers;
    int num_seeds;
    bool is_paused;
    bool is_seeding;
    bool is_finished;
    int64_t all_time_upload;
    int64_t all_time_download;
    const char* name;
    const char* save_path;
    const char* info_hash;
} lt_torrent_status_t;

typedef struct {
    const char* url;
    int tier;
    int num_peers;
    bool is_working;
} lt_tracker_info_t;

int lt_get_tracker_count(lt_torrent_t* torrent);
bool lt_get_trackers(lt_torrent_t* torrent, lt_tracker_info_t* out_trackers, int max_count);
bool lt_get_status(lt_torrent_t* torrent, lt_torrent_status_t* out_status);

typedef struct {
    const char* path;
    int64_t size;
    float progress;
    int priority;
} lt_file_info_t;

int lt_get_file_count(lt_torrent_t* torrent);
bool lt_get_files(lt_torrent_t* torrent, lt_file_info_t* out_files, int count);
void lt_set_file_priority(lt_torrent_t* torrent, int file_index, int priority);

typedef struct {
    const char* ip;
    int port;
    const char* client;
    int download_rate;
    int upload_rate;
    float progress;
} lt_peer_info_t;

int lt_get_peer_count(lt_torrent_t* torrent);
bool lt_get_peers(lt_torrent_t* torrent, lt_peer_info_t* out_peers, int max_count);

void* lt_save_resume_data(lt_torrent_t* torrent, int* out_len);

int lt_session_torrent_count(lt_session_t* session);
lt_torrent_t* lt_session_get_torrent(lt_session_t* session, int index);

#ifdef __cplusplus
}
#endif

#endif // LIBTORRENTKIT_H
