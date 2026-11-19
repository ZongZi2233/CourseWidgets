#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

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
