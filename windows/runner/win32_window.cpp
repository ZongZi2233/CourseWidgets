#include "win32_window.h"

#include <algorithm>
#include <cmath>
#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_NCRENDERING_POLICY
#define DWMWA_NCRENDERING_POLICY 2
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_COLOR_NONE
#define DWMWA_COLOR_NONE 0xFFFFFFFE
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASSEX window_class{};
    window_class.cbSize = sizeof(WNDCLASSEX);
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hIcon = (HICON)LoadImage(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                          GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR);
    window_class.hIconSm = (HICON)LoadImage(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                            GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClassEx(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  // 显式为窗口设置高分辨率大图标(任务栏/Alt-Tab)与小图标(标题栏/托盘)
  HICON hIconBig = (HICON)LoadImage(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR);
  HICON hIconSmall = (HICON)LoadImage(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
  if (hIconBig) SendMessage(window, WM_SETICON, ICON_BIG, (LPARAM)hIconBig);
  if (hIconSmall) SendMessage(window, WM_SETICON, ICON_SMALL, (LPARAM)hIconSmall);

  ApplyBorderlessDwmStyle(window);
  UpdateTheme(window);
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);

  return OnCreate();
}

bool Win32Window::CreateCentered(const std::wstring& title, const Size& size) {
  POINT cursor = {0, 0};
  GetCursorPos(&cursor);
  HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = {sizeof(mi)};
  if (!GetMonitorInfo(monitor, &mi)) {
    return Create(title, Point(100, 100), size);
  }
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi > 0 ? dpi / 96.0 : 1.0;

  int work_w_logical = static_cast<int>(
      std::lround((mi.rcWork.right - mi.rcWork.left) / scale_factor));
  int work_h_logical = static_cast<int>(
      std::lround((mi.rcWork.bottom - mi.rcWork.top) / scale_factor));
  int left_logical = static_cast<int>(std::lround(mi.rcWork.left / scale_factor));
  int top_logical = static_cast<int>(std::lround(mi.rcWork.top / scale_factor));

  int origin_x =
      left_logical + std::max(0, (work_w_logical - static_cast<int>(size.width)) / 2);
  int origin_y =
      top_logical + std::max(0, (work_h_logical - static_cast<int>(size.height)) / 2);

  return Create(title, Point(static_cast<unsigned int>(std::max(0, origin_x)),
                             static_cast<unsigned int>(std::max(0, origin_y))),
                size);
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::ShowOrRestore() {
  if (!window_handle_ || !IsWindow(window_handle_)) {
    return;
  }
  ApplyBorderlessDwmStyle(window_handle_);
  if (IsIconic(window_handle_)) {
    ShowWindow(window_handle_, SW_RESTORE);
  } else {
    ShowWindow(window_handle_, SW_SHOW);
  }
  BringWindowToTop(window_handle_);
  SetForegroundWindow(window_handle_);
  if (child_content_ != nullptr) {
    SetFocus(child_content_);
  }
}

void Win32Window::HideWindow() {
  if (window_handle_ && IsWindow(window_handle_)) {
    ShowWindow(window_handle_, SW_HIDE);
  }
}

void Win32Window::ApplyBorderlessDwmStyle(HWND window) {
  if (!window || !IsWindow(window)) {
    return;
  }
  DWMNCRENDERINGPOLICY policy = DWMNCRP_USEWINDOWSTYLE;
  DwmSetWindowAttribute(window, DWMWA_NCRENDERING_POLICY, &policy,
                        sizeof(policy));

  // Windows 11 原生圆角 (DWMWCP_ROUND = 2) + 彻底隐藏原生主题色边框与标题栏色
  int corner_preference = 2;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  COLORREF color_none = DWMWA_COLOR_NONE;
  DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &color_none,
                        sizeof(color_none));
  DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &color_none,
                        sizeof(color_none));
}

UINT Win32Window::GetWakeUpMessageId() {
  static const UINT msg = RegisterWindowMessageW(L"CourseWidgets_WakeUpWindow");
  return msg;
}

void Win32Window::SetPreventCloseOnHide(bool prevent_close) {
  prevent_close_on_hide_ = prevent_close;
}

void Win32Window::ForceClose() {
  is_exiting_ = true;
  Destroy();
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_NCCALCSIZE:
      if (borderless_titlebar_) {
        if (wparam == TRUE) {
          auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
          const RECT proposed = params->rgrc[0];
          const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
          if (IsZoomed(hwnd)) {
            MONITORINFO monitor = {sizeof(monitor)};
            if (GetMonitorInfoW(
                    MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                    &monitor)) {
              params->rgrc[0] = monitor.rcWork;
            }
          } else {
            params->rgrc[0].top = proposed.top;
          }
          return result;
        } else {
          auto* proposed = reinterpret_cast<RECT*>(lparam);
          const RECT original = *proposed;
          const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
          proposed->top = original.top;
          return result;
        }
      }
      break;

    case WM_ERASEBKGND:
      // 由 Flutter/DirectComposition 直接接管绘制，禁止 GDI 擦除造成首帧白/黑闪烁
      return 1;

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      ApplyBorderlessDwmStyle(hwnd);
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      ApplyBorderlessDwmStyle(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
