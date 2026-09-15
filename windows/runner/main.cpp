#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
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
  
  // Custom window style without native titlebar
  HWND hwnd = window.GetHandle();
  
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  
  LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED;
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle);
  
  SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
  
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
