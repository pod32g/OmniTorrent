#include "libtorrentkit.h"

#include <libtorrent/session.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/bencode.hpp>
#include <libtorrent/peer_info.hpp>
#include <libtorrent/session_params.hpp>
#include <libtorrent/settings_pack.hpp>

#include <vector>
#include <string>
#include <fstream>
#include <mutex>
#include <cstring>
#include <sstream>

namespace lt = libtorrent;

// --- Internal structures ---

struct lt_torrent_t {
    lt::torrent_handle handle;
    std::string name_buf;
    std::string save_path_buf;
    std::string info_hash_buf;
    std::vector<std::string> file_path_bufs;
    std::vector<std::string> peer_ip_bufs;
    std::vector<std::string> peer_client_bufs;
};

struct lt_session_t {
    lt::session session;
    std::vector<lt_torrent_t*> torrents;
    std::mutex mutex;

    lt_session_t(int port) : session(make_params(port)) {}

    static lt::session_params make_params(int port) {
        lt::settings_pack sp;
        sp.set_int(lt::settings_pack::alert_mask,
            lt::alert_category::status |
            lt::alert_category::storage |
            lt::alert_category::error);
        std::string iface = "0.0.0.0:" + std::to_string(port);
        sp.set_str(lt::settings_pack::listen_interfaces, iface);
        return lt::session_params(sp);
    }
};

// --- Session lifecycle ---

lt_session_t* lt_session_create(int listen_port) {
    try {
        return new lt_session_t(listen_port);
    } catch (...) {
        return nullptr;
    }
}

void lt_session_destroy(lt_session_t* session) {
    if (!session) return;
    {
        std::lock_guard<std::mutex> lock(session->mutex);
        for (auto* t : session->torrents) {
            delete t;
        }
        session->torrents.clear();
    }
    delete session;
}

// --- Session settings ---

void lt_session_set_download_limit(lt_session_t* session, int bytes_per_sec) {
    if (!session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::download_rate_limit, bytes_per_sec);
    session->session.apply_settings(sp);
}

void lt_session_set_upload_limit(lt_session_t* session, int bytes_per_sec) {
    if (!session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::upload_rate_limit, bytes_per_sec);
    session->session.apply_settings(sp);
}

// --- Adding torrents ---

static lt_torrent_t* wrap_handle(lt_session_t* session, lt::torrent_handle h) {
    auto* t = new lt_torrent_t();
    t->handle = h;
    std::lock_guard<std::mutex> lock(session->mutex);
    session->torrents.push_back(t);
    return t;
}

lt_torrent_t* lt_add_torrent_magnet(lt_session_t* session, const char* magnet_uri, const char* save_path) {
    if (!session || !magnet_uri || !save_path) return nullptr;
    try {
        lt::add_torrent_params atp = lt::parse_magnet_uri(magnet_uri);
        atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

lt_torrent_t* lt_add_torrent_file(lt_session_t* session, const char* torrent_path, const char* save_path) {
    if (!session || !torrent_path || !save_path) return nullptr;
    try {
        lt::add_torrent_params atp;
        atp.ti = std::make_shared<lt::torrent_info>(std::string(torrent_path));
        atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

lt_torrent_t* lt_add_torrent_resume(lt_session_t* session, const void* resume_data, int resume_data_len, const char* save_path) {
    if (!session || !resume_data || resume_data_len <= 0) return nullptr;
    try {
        auto buf = std::vector<char>(
            static_cast<const char*>(resume_data),
            static_cast<const char*>(resume_data) + resume_data_len
        );
        lt::add_torrent_params atp = lt::read_resume_data(buf);
        if (save_path) atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

// --- Torrent control ---

void lt_torrent_pause(lt_torrent_t* torrent) {
    if (!torrent) return;
    torrent->handle.pause();
}

void lt_torrent_resume(lt_torrent_t* torrent) {
    if (!torrent) return;
    torrent->handle.resume();
}

void lt_torrent_remove(lt_session_t* session, lt_torrent_t* torrent, bool delete_files) {
    if (!session || !torrent) return;
    lt::remove_flags_t flags = {};
    if (delete_files) flags = lt::session::delete_files;
    session->session.remove_torrent(torrent->handle, flags);
    {
        std::lock_guard<std::mutex> lock(session->mutex);
        auto& v = session->torrents;
        v.erase(std::remove(v.begin(), v.end(), torrent), v.end());
    }
    delete torrent;
}

void lt_torrent_set_sequential(lt_torrent_t* torrent, bool sequential) {
    if (!torrent) return;
    if (sequential)
        torrent->handle.set_flags(lt::torrent_flags::sequential_download);
    else
        torrent->handle.unset_flags(lt::torrent_flags::sequential_download);
}

void lt_torrent_set_download_limit(lt_torrent_t* torrent, int bytes_per_sec) {
    if (!torrent) return;
    torrent->handle.set_download_limit(bytes_per_sec);
}

void lt_torrent_set_upload_limit(lt_torrent_t* torrent, int bytes_per_sec) {
    if (!torrent) return;
    torrent->handle.set_upload_limit(bytes_per_sec);
}

// --- Torrent status ---

bool lt_get_status(lt_torrent_t* torrent, lt_torrent_status_t* out) {
    if (!torrent || !out) return false;
    try {
        auto st = torrent->handle.status();
        out->state = static_cast<int>(st.state);
        out->progress = st.progress;
        out->total_size = st.total_wanted;
        out->total_done = st.total_wanted_done;
        out->download_rate = st.download_rate;
        out->upload_rate = st.upload_rate;
        out->num_peers = st.num_peers;
        out->num_seeds = st.num_seeds;
        out->is_paused = (st.flags & lt::torrent_flags::paused) != 0;
        out->is_seeding = st.is_seeding;
        out->is_finished = st.is_finished;
        out->all_time_upload = st.all_time_upload;
        out->all_time_download = st.all_time_download;

        torrent->name_buf = st.name;
        out->name = torrent->name_buf.c_str();

        torrent->save_path_buf = st.save_path;
        out->save_path = torrent->save_path_buf.c_str();

        std::ostringstream oss;
        oss << st.info_hashes.get_best();
        torrent->info_hash_buf = oss.str();
        out->info_hash = torrent->info_hash_buf.c_str();

        return true;
    } catch (...) {
        return false;
    }
}

// --- File management ---

int lt_get_file_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    auto ti = torrent->handle.torrent_file();
    if (!ti) return 0;
    return ti->num_files();
}

bool lt_get_files(lt_torrent_t* torrent, lt_file_info_t* out_files, int count) {
    if (!torrent || !out_files || count <= 0) return false;
    try {
        auto ti = torrent->handle.torrent_file();
        if (!ti) return false;

        auto& fs = ti->files();
        std::vector<int64_t> progress;
        torrent->handle.file_progress(progress);
        auto priorities = torrent->handle.get_file_priorities();

        torrent->file_path_bufs.resize(count);

        int n = std::min(count, ti->num_files());
        for (int i = 0; i < n; i++) {
            torrent->file_path_bufs[i] = fs.file_path(lt::file_index_t(i));
            out_files[i].path = torrent->file_path_bufs[i].c_str();
            out_files[i].size = fs.file_size(lt::file_index_t(i));
            out_files[i].progress = (out_files[i].size > 0)
                ? static_cast<float>(progress[i]) / static_cast<float>(out_files[i].size)
                : 1.0f;
            out_files[i].priority = static_cast<int>(priorities[i]);
        }
        return true;
    } catch (...) {
        return false;
    }
}

void lt_set_file_priority(lt_torrent_t* torrent, int file_index, int priority) {
    if (!torrent) return;
    torrent->handle.file_priority(
        lt::file_index_t(file_index),
        lt::download_priority_t(static_cast<uint8_t>(priority))
    );
}

// --- Peers ---

int lt_get_peer_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    return torrent->handle.status().num_peers;
}

bool lt_get_peers(lt_torrent_t* torrent, lt_peer_info_t* out_peers, int max_count) {
    if (!torrent || !out_peers || max_count <= 0) return false;
    try {
        std::vector<lt::peer_info> peers;
        torrent->handle.get_peer_info(peers);

        int n = std::min(max_count, static_cast<int>(peers.size()));
        torrent->peer_ip_bufs.resize(n);
        torrent->peer_client_bufs.resize(n);

        for (int i = 0; i < n; i++) {
            torrent->peer_ip_bufs[i] = peers[i].ip.address().to_string();
            out_peers[i].ip = torrent->peer_ip_bufs[i].c_str();
            out_peers[i].port = peers[i].ip.port();
            torrent->peer_client_bufs[i] = peers[i].client;
            out_peers[i].client = torrent->peer_client_bufs[i].c_str();
            out_peers[i].download_rate = peers[i].down_speed;
            out_peers[i].upload_rate = peers[i].up_speed;
            out_peers[i].progress = peers[i].progress;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// --- Trackers ---

int lt_get_tracker_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    auto trackers = torrent->handle.trackers();
    return static_cast<int>(trackers.size());
}

bool lt_get_trackers(lt_torrent_t* torrent, lt_tracker_info_t* out_trackers, int max_count) {
    if (!torrent || !out_trackers || max_count <= 0) return false;
    try {
        auto trackers = torrent->handle.trackers();
        int n = std::min(max_count, static_cast<int>(trackers.size()));
        // Store URLs in thread-local storage to keep pointers valid
        static thread_local std::vector<std::string> tracker_url_bufs;
        tracker_url_bufs.resize(n);
        for (int i = 0; i < n; i++) {
            tracker_url_bufs[i] = trackers[i].url;
            out_trackers[i].url = tracker_url_bufs[i].c_str();
            out_trackers[i].tier = trackers[i].tier;
            // num_peers from endpoints if available
            int peers = 0;
            for (auto& ep : trackers[i].endpoints) {
                for (auto& info : ep.info_hashes) {
                    peers += info.scrape_complete + info.scrape_incomplete;
                }
            }
            out_trackers[i].num_peers = peers;
            out_trackers[i].is_working = !trackers[i].endpoints.empty() &&
                trackers[i].endpoints[0].info_hashes[lt::protocol_version::V1].fails == 0;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// --- Resume data ---

void* lt_save_resume_data(lt_torrent_t* torrent, int* out_len) {
    if (!torrent || !out_len) return nullptr;
    try {
        // The deprecated write_resume_data() on torrent_handle returns an entry.
        // Bencode it directly to get the resume data buffer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        lt::entry e = torrent->handle.write_resume_data();
#pragma clang diagnostic pop
        std::vector<char> buf;
        lt::bencode(std::back_inserter(buf), e);
        void* result = malloc(buf.size());
        if (result) {
            memcpy(result, buf.data(), buf.size());
            *out_len = static_cast<int>(buf.size());
        }
        return result;
    } catch (...) {
        *out_len = 0;
        return nullptr;
    }
}

// --- Enumerate active torrents ---

int lt_session_torrent_count(lt_session_t* session) {
    if (!session) return 0;
    std::lock_guard<std::mutex> lock(session->mutex);
    return static_cast<int>(session->torrents.size());
}

lt_torrent_t* lt_session_get_torrent(lt_session_t* session, int index) {
    if (!session) return nullptr;
    std::lock_guard<std::mutex> lock(session->mutex);
    if (index < 0 || index >= static_cast<int>(session->torrents.size())) return nullptr;
    return session->torrents[index];
}
