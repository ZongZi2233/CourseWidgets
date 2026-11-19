#include "flutter_window.h"

#include <windows.h>
#include <flutter/standard_method_codec.h>
#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int required =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (required <= 1) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(required), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), required);
  wide.pop_back();
  return wide;
}

bool LaunchDetachedHiddenProcess(const std::string& command_line_utf8,
                                 const std::string& working_dir_utf8) {
  std::wstring cmd_wide = Utf8ToWide(command_line_utf8);
  if (cmd_wide.empty()) {
    return false;
  }
  std::wstring work_dir_wide = Utf8ToWide(working_dir_utf8);
  const wchar_t* work_dir_ptr =
      work_dir_wide.empty() ? nullptr : work_dir_wide.c_str();

  STARTUPINFOW si{};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;

  PROCESS_INFORMATION pi{};
  const DWORD base_flags = CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP;
  BOOL created = CreateProcessW(
      nullptr, cmd_wide.data(), nullptr, nullptr, FALSE,
      base_flags | CREATE_BREAKAWAY_FROM_JOB, nullptr, work_dir_ptr, &si, &pi);
  if (!created && GetLastError() == ERROR_ACCESS_DENIED) {
    // Retry without breakaway when the parent Job object disallows breakaway.
    std::wstring retry_cmd = Utf8ToWide(command_line_utf8);
    created = CreateProcessW(nullptr, retry_cmd.data(), nullptr, nullptr, FALSE,
                             base_flags, nullptr, work_dir_ptr, &si, &pi);
  }
  if (!created) {
    return false;
  }
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  desktop_window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.zongzi.schedule/desktop_window",
          &flutter::StandardMethodCodec::GetInstance());
  desktop_window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "showOrRestore") {
          this->ShowOrRestore();
          if (flutter_controller_) {
            flutter_controller_->ForceRedraw();
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "hideWindow") {
          this->HideWindow();
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "applyDwmStyle") {
          Win32Window::ApplyBorderlessDwmStyle(this->GetHandle());
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "setPreventCloseOnHide") {
          if (const auto* val = std::get_if<bool>(call.arguments())) {
            this->SetPreventCloseOnHide(*val);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "forceClose") {
          this->SetPreventCloseOnHide(false);
          this->HideWindow();
          result->Success(flutter::EncodableValue(true));
          PostQuitMessage(0);
        } else if (call.method_name() == "launchDetachedProcess") {
          bool launched = false;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            std::string cmd_line;
            std::string work_dir;
            auto cmd_it = args->find(flutter::EncodableValue("commandLine"));
            if (cmd_it != args->end()) {
              if (const auto* s = std::get_if<std::string>(&cmd_it->second)) {
                cmd_line = *s;
              }
            }
            auto wd_it =
                args->find(flutter::EncodableValue("workingDirectory"));
            if (wd_it != args->end()) {
              if (const auto* s = std::get_if<std::string>(&wd_it->second)) {
                work_dir = *s;
              }
            }
            launched = LaunchDetachedHiddenProcess(cmd_line, work_dir);
          }
          result->Success(flutter::EncodableValue(launched));
        } else {
          result->NotImplemented();
        }
      });

  return true;
}

void FlutterWindow::OnDestroy() {
  desktop_window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  if (message == Win32Window::GetWakeUpMessageId()) {
    ShowOrRestore();
    if (flutter_controller_) {
      flutter_controller_->ForceRedraw();
    }
    if (desktop_window_channel_) {
      desktop_window_channel_->InvokeMethod("onNativeWakeUp", nullptr);
    }
    return 0;
  }

  switch (message) {
    case WM_CLOSE:
      if (ShouldPreventCloseOnHide()) {
        HideWindow();
        if (desktop_window_channel_) {
          desktop_window_channel_->InvokeMethod("onNativeCloseRequested",
                                                nullptr);
        }
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
