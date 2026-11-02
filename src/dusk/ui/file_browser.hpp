#pragma once

#include "modal.hpp"

#include <filesystem>
#include <functional>
#include <optional>
#include <vector>

namespace dusk::ui {

// In-app replacement for the system file picker on platforms without one (UWP / Xbox).
class FileBrowser final : public Modal {
public:
    enum class Mode {
        DiscImage,
        Folder,
    };
    using SelectCallback = std::function<void(const std::filesystem::path&)>;

    FileBrowser(Mode mode, std::filesystem::path initialDirectory, SelectCallback onSelected);

    void update() override;

    // Directory the app can always read and write (the package's LocalState folder on UWP).
    static std::filesystem::path app_storage_root();

private:
    enum class View {
        Drives,
        Directory,
    };
    struct PendingNavigation {
        View view;
        std::filesystem::path path;
    };

    static Props make_props(Mode mode, FileBrowser* self);
    void navigate(View view, std::filesystem::path path);
    void select(std::filesystem::path path);
    void rebuild();
    bool can_go_up() const;

    Mode mMode;
    View mView = View::Directory;
    std::filesystem::path mCurrent;
    SelectCallback mOnSelected;
    std::optional<PendingNavigation> mPending;
    std::optional<std::filesystem::path> mPendingSelection;
};

// Pushes a FileBrowser on top of the current document.
void open_file_browser(FileBrowser::Mode mode, std::filesystem::path initialDirectory,
    FileBrowser::SelectCallback onSelected);

}  // namespace dusk::ui
