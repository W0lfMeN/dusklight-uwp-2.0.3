#include "file_browser.hpp"

#include "dusk/app_info.hpp"

#include <SDL3/SDL_filesystem.h>
#include <SDL3/SDL_stdinc.h>
#include <borealis/io.hpp>
#include <m_Do/m_Do_audio.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <string>
#include <string_view>
#include <utility>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace dusk::ui {
namespace {

constexpr std::array kDiscExtensions{
    "iso", "gcm", "ciso", "gcz", "nfs", "rvz", "wbfs", "wia", "tgc",
};

std::string lowercase(std::string value) {
    std::ranges::transform(value, value.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

bool is_disc_image(const std::filesystem::path& path) {
    std::string ext = lowercase(borealis::io::fs_path_to_string(path.extension()));
    if (!ext.empty() && ext.front() == '.') {
        ext.erase(ext.begin());
    }
    return std::ranges::find(kDiscExtensions, std::string_view{ext}) != kDiscExtensions.end();
}

bool directory_exists(const std::filesystem::path& path) {
    std::error_code ec;
    return !path.empty() && std::filesystem::is_directory(path, ec);
}

std::filesystem::path normalized(const std::filesystem::path& path) {
    std::error_code ec;
    auto result = std::filesystem::absolute(path, ec);
    return ec ? path.lexically_normal() : result.lexically_normal();
}

bool is_root(const std::filesystem::path& path) {
    return path.has_root_path() && path.relative_path().empty();
}

std::vector<std::filesystem::path> list_drives() {
    std::vector<std::filesystem::path> drives;
#if defined(_WIN32)
    std::array<wchar_t, 512> buffer{};
    const DWORD length = GetLogicalDriveStringsW(static_cast<DWORD>(buffer.size()), buffer.data());
    if (length == 0 || length >= buffer.size()) {
        return drives;
    }
    for (const wchar_t* drive = buffer.data(); *drive != L'\0';) {
        const std::wstring_view name{drive};
        std::filesystem::path root{name};
        if (directory_exists(root)) {
            drives.push_back(std::move(root));
        }
        drive += name.size() + 1;
    }
#endif
    return drives;
}

}  // namespace

std::filesystem::path FileBrowser::app_storage_root() {
    const std::string orgName{AppInfo.orgName};
    const std::string appName{AppInfo.appName};
    char* preferencePath = SDL_GetPrefPath(orgName.c_str(), appName.c_str());
    if (preferencePath == nullptr) {
        return {};
    }
    const auto path = normalized(borealis::io::fs_path_from_utf8(preferencePath));
    SDL_free(preferencePath);
    // On UWP the preference path lives inside the package's LocalState folder, which is also
    // where the Device Portal uploads files.
    for (auto parent = path; !parent.empty() && !is_root(parent); parent = parent.parent_path()) {
        if (lowercase(borealis::io::fs_path_to_string(parent.filename())) == "localstate") {
            return parent;
        }
    }
    return path;
}

Modal::Props FileBrowser::make_props(Mode mode, FileBrowser* self) {
    std::vector<ModalAction> actions{
        ModalAction{
            .label = "Up",
            .onPressed =
                [self](Modal&) {
                    if (is_root(self->mCurrent)) {
                        self->mPending = PendingNavigation{View::Drives, {}};
                    } else {
                        self->mPending =
                            PendingNavigation{View::Directory, self->mCurrent.parent_path()};
                    }
                },
            .isDisabled = [self] { return !self->can_go_up(); },
        },
        ModalAction{
            .label = "LocalState",
            .onPressed =
                [self](Modal&) {
                    self->mPending = PendingNavigation{View::Directory, app_storage_root()};
                },
        },
        ModalAction{
            .label = "Drives",
            .onPressed =
                [self](Modal&) { self->mPending = PendingNavigation{View::Drives, {}}; },
            .isDisabled = [self] { return self->mView == View::Drives; },
        },
    };
    if (mode == Mode::Folder) {
        actions.push_back(ModalAction{
            .label = "Use This Folder",
            .onPressed = [self](Modal&) { self->mPendingSelection = self->mCurrent; },
            .isDisabled =
                [self] { return self->mView != View::Directory || !directory_exists(self->mCurrent); },
        });
    }
    actions.push_back(ModalAction{
        .label = "Cancel",
        .onPressed =
            [](Modal& modal) {
                mDoAud_seStartMenu(kSoundWindowClose);
                modal.pop();
            },
    });
    return Props{
        .title = mode == Mode::Folder ? "Select Data Folder" : "Select Disc Image",
        .actions = std::move(actions),
        .variant = "file-browser",
    };
}

FileBrowser::FileBrowser(
    Mode mode, std::filesystem::path initialDirectory, SelectCallback onSelected)
    : Modal(make_props(mode, this)), mMode(mode), mOnSelected(std::move(onSelected)) {
    if (directory_exists(initialDirectory)) {
        navigate(View::Directory, std::move(initialDirectory));
    } else if (auto root = app_storage_root(); directory_exists(root)) {
        navigate(View::Directory, std::move(root));
    } else {
        navigate(View::Drives, {});
    }
}

void FileBrowser::update() {
    Modal::update();
    if (mPendingSelection) {
        select(*std::exchange(mPendingSelection, std::nullopt));
        return;
    }
    if (mPending) {
        auto pending = *std::exchange(mPending, std::nullopt);
        mDoAud_seStartMenu(kSoundItemChange);
        navigate(pending.view, std::move(pending.path));
    }
}

bool FileBrowser::can_go_up() const {
    if (mView != View::Directory) {
        return false;
    }
#if defined(_WIN32)
    if (is_root(mCurrent)) {
        return true;
    }
#endif
    return !is_root(mCurrent) && directory_exists(mCurrent.parent_path());
}

void FileBrowser::navigate(View view, std::filesystem::path path) {
    if (view == View::Directory) {
        path = normalized(path);
        if (!directory_exists(path)) {
            set_body(escape(borealis::io::fs_path_to_string(path)) +
                     "<br/>That folder is not available.");
            return;
        }
        mCurrent = std::move(path);
    }
    mView = view;
    rebuild();
}

void FileBrowser::select(std::filesystem::path path) {
    auto callback = mOnSelected;
    mDoAud_seStartMenu(kSoundItemChange);
    pop();
    if (callback) {
        callback(path);
    }
}

void FileBrowser::rebuild() {
    auto& pane = content_pane();
    pane.clear();

    if (mView == View::Drives) {
        const auto drives = list_drives();
        set_body(drives.empty() ? "No drives are available." : "Select a drive.");
        for (const auto& drive : drives) {
            pane.add_button(borealis::io::fs_path_to_string(drive)).on_pressed([this, drive] {
                mPending = PendingNavigation{View::Directory, drive};
            });
        }
        focus();
        return;
    }

    std::vector<std::filesystem::path> directories;
    std::vector<std::filesystem::path> files;
    std::error_code ec;
    for (std::filesystem::directory_iterator it{mCurrent, ec}, end; !ec && it != end;
        it.increment(ec))
    {
        const auto& path = it->path();
        const auto name = borealis::io::fs_path_to_string(path.filename());
        if (name.empty() || name.front() == '.') {
            continue;
        }
        std::error_code statusError;
        const auto status = it->status(statusError);
        if (statusError) {
            continue;
        }
        if (std::filesystem::is_directory(status)) {
            directories.push_back(path);
        } else if (mMode == Mode::DiscImage && std::filesystem::is_regular_file(status) &&
                   is_disc_image(path))
        {
            files.push_back(path);
        }
    }

    const auto byName = [](const std::filesystem::path& a, const std::filesystem::path& b) {
        return lowercase(borealis::io::fs_path_to_string(a.filename())) <
               lowercase(borealis::io::fs_path_to_string(b.filename()));
    };
    std::ranges::sort(directories, byName);
    std::ranges::sort(files, byName);

    for (const auto& directory : directories) {
        pane.add_button("[" + borealis::io::fs_path_to_string(directory.filename()) + "]")
            .on_pressed([this, directory] {
                mPending = PendingNavigation{View::Directory, directory};
            });
    }
    for (const auto& file : files) {
        pane.add_button(borealis::io::fs_path_to_string(file.filename())).on_pressed([this, file] {
            mPendingSelection = file;
        });
    }

    Rml::String body = escape(borealis::io::fs_path_to_string(mCurrent));
    if (ec) {
        body += "<br/>" + escape("This folder could not be read: " + ec.message());
    } else if (directories.empty() && files.empty()) {
        body += mMode == Mode::DiscImage ? "<br/>No disc images in this folder." :
                                           "<br/>This folder has no subfolders.";
    }
    set_body(body);
    focus();
}

void open_file_browser(FileBrowser::Mode mode, std::filesystem::path initialDirectory,
    FileBrowser::SelectCallback onSelected) {
    auto browser =
        std::make_unique<FileBrowser>(mode, std::move(initialDirectory), std::move(onSelected));
    if (auto* host = top_document()) {
        host->push(std::move(browser));
    } else {
        push_document(std::move(browser));
    }
    if (auto* doc = top_document()) {
        doc->focus();
    }
}

}  // namespace dusk::ui
