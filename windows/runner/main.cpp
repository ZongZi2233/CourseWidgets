#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"
#include "resource.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 显式声明全局 AppUserModelID，使 Windows 任务栏与 Action Center 通知精准匹配图标
  SetCurrentProcessExplicitAppUserModelID(L"CourseWidgets Beta");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Single instance check for CourseWidgets Beta
  HANDLE hMutex = CreateMutex(NULL, TRUE, L"CourseWidgetsBeta_SingleInstance_Mutex");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existingHwnd = FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"CourseWidgets Beta");
    if (!existingHwnd) {
      existingHwnd = FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"CourseWidgets");
    }
    if (existingHwnd) {
      if (IsIconic(existingHwnd)) {
        ShowWindow(existingHwnd, SW_RESTORE);
      }
      SetForegroundWindow(existingHwnd);
    }
    CloseHandle(hMutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Enable Impeller graphics engine
  _wputenv(L"FLUTTER_ENABLE_IMPELLER=1");

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  
  // Set window title and icon
  if (!window.Create(L"CourseWidgets Beta", origin, size)) {
    return EXIT_FAILURE;
  }
  
  HWND hwnd = window.GetHandle();
  HINSTANCE hInst = GetModuleHandle(nullptr);
  HICON hIconBig = (HICON)LoadImage(hInst, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
                                    LR_DEFAULTCOLOR);
  HICON hIconSmall = (HICON)LoadImage(hInst, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                                      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
                                      LR_DEFAULTCOLOR);
  if (hIconBig) {
    SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)hIconBig);
  }
  if (hIconSmall) {
    SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)hIconSmall);
  }
  
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  
  if (hMutex) {
    ReleaseMutex(hMutex);
    CloseHandle(hMutex);
  }
  
  return EXIT_SUCCESS;
}
