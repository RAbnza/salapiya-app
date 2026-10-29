#include "win32_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
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

// A maximized window covers its whole monitor when the taskbar auto-hides;
// leaving one pixel on the taskbar's edge lets it still slide in.
void LeaveAutoHideTaskbarEdge(HWND hwnd, RECT& rect) {
  MONITORINFO info{sizeof(info)};
  if (!GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                      &info)) {
    return;
  }
  for (const UINT edge : {ABE_BOTTOM, ABE_TOP, ABE_LEFT, ABE_RIGHT}) {
    APPBARDATA bar{sizeof(bar)};
    bar.uEdge = edge;
    bar.rc = info.rcMonitor;
    if (!SHAppBarMessage(ABM_GETAUTOHIDEBAREX, &bar)) continue;
    switch (edge) {
      case ABE_BOTTOM: rect.bottom -= 1; break;
      case ABE_TOP: rect.top += 1; break;
      case ABE_LEFT: rect.left += 1; break;
      case ABE_RIGHT: rect.right -= 1; break;
    }
    return;
  }
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
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
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

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
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
      if (wparam != SIZE_MINIMIZED && (wparam == SIZE_MAXIMIZED) != maximized_) {
        maximized_ = wparam == SIZE_MAXIMIZED;
        NotifyFrameState();
      }
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      active_ = LOWORD(wparam) != WA_INACTIVE;
      NotifyFrameState();
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_SETTINGCHANGE:
    case WM_THEMECHANGED:
      UpdateTheme(hwnd);
      return DefWindowProc(hwnd, message, wparam, lparam);

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;

    // Custom frame: the client area starts at the window's top edge, so the
    // app's title bar replaces the caption. Left, right and bottom keep the
    // native frame. A maximized window hides its frame off-screen, so the
    // top gets the same padding back.
    case WM_NCCALCSIZE:
      if (custom_frame_ && wparam) {
        auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        const LONG top = params->rgrc[0].top;
        const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
        if (result != 0) return result;
        params->rgrc[0].top = top;
        if (IsZoomed(hwnd)) {
          params->rgrc[0].top += ResizeBorderHeight();
          LeaveAutoHideTaskbarEdge(hwnd, params->rgrc[0]);
        }
        return 0;
      }
      break;

    case WM_NCHITTEST:
      if (custom_frame_) {
        // The native frame answers for its borders.
        const LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
        if (hit != HTCLIENT) return hit;
        return FrameHitTest({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
      }
      break;

    // The app draws the maximize button, but Windows sees HTMAXBUTTON there
    // (for Snap Layouts), so its pointer input arrives here.
    case WM_NCMOUSEMOVE:
      if (custom_frame_) {
        if (wparam == HTMAXBUTTON) {
          if (max_button_ == CaptionState::kNone) {
            TRACKMOUSEEVENT track{sizeof(track), TME_LEAVE | TME_NONCLIENT,
                                  hwnd, HOVER_DEFAULT};
            TrackMouseEvent(&track);
          }
          SetMaxButton(max_pressed_ ? CaptionState::kPressed
                                    : CaptionState::kHover);
        } else {
          max_pressed_ = false;
          SetMaxButton(CaptionState::kNone);
        }
      }
      break;

    case WM_NCMOUSELEAVE:
      if (custom_frame_) {
        max_pressed_ = false;
        SetMaxButton(CaptionState::kNone);
      }
      break;

    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (custom_frame_ && wparam == HTMAXBUTTON) {
        max_pressed_ = true;
        SetMaxButton(CaptionState::kPressed);
        return 0;
      }
      break;

    case WM_NCLBUTTONUP:
      if (custom_frame_ && wparam == HTMAXBUTTON) {
        const bool clicked = max_pressed_;
        max_pressed_ = false;
        SetMaxButton(CaptionState::kHover);
        if (clicked) {
          PostMessage(hwnd, WM_SYSCOMMAND,
                      IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE, 0);
        }
        return 0;
      }
      break;
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
  SetWindowSubclass(content, ContentProc, 1,
                    reinterpret_cast<DWORD_PTR>(this));
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

// static
LRESULT CALLBACK Win32Window::ContentProc(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam,
                                          UINT_PTR, DWORD_PTR data) noexcept {
  if (message == WM_NCHITTEST) {
    // Over caption space, the resize band and the maximize button, let the
    // top-level window answer (HTCAPTION, HTTOP, HTMAXBUTTON).
    auto that = reinterpret_cast<Win32Window*>(data);
    if (that->custom_frame_ &&
        that->FrameHitTest({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)}) !=
            HTCLIENT) {
      return HTTRANSPARENT;
    }
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

bool Win32Window::EnableCustomFrame() {
  if (!window_handle_) return false;
  custom_frame_ = true;
  maximized_ = IsZoomed(window_handle_) != 0;
  SetWindowPos(window_handle_, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOOWNERZORDER | SWP_NOACTIVATE);
  if (child_content_ != nullptr) {
    RECT frame = GetClientArea();
    MoveWindow(child_content_, frame.left, frame.top, frame.right - frame.left,
               frame.bottom - frame.top, TRUE);
  }
  return true;
}

void Win32Window::SetCaptionRegions(double height, const LogicalRect& maximize,
                                    std::vector<LogicalRect> interactive) {
  caption_height_ = height;
  max_rect_ = maximize;
  interactive_ = std::move(interactive);
}

int Win32Window::ResizeBorderHeight() const {
  const UINT dpi = GetDpiForWindow(window_handle_);
  return GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi) +
         GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi);
}

LRESULT Win32Window::FrameHitTest(POINT point) const {
  ScreenToClient(window_handle_, &point);
  const int border = ResizeBorderHeight();
  if (!IsZoomed(window_handle_) && point.y >= 0 && point.y < border) {
    RECT client;
    GetClientRect(window_handle_, &client);
    if (point.x < border) return HTTOPLEFT;
    if (point.x >= client.right - border) return HTTOPRIGHT;
    return HTTOP;
  }
  // The app reports its regions in logical pixels.
  const double scale = GetDpiForWindow(window_handle_) / 96.0;
  const double x = point.x / scale, y = point.y / scale;
  if (y < 0 || y >= caption_height_) return HTCLIENT;
  for (const auto& rect : interactive_) {
    if (rect.Contains(x, y)) return HTCLIENT;
  }
  if (max_rect_.Contains(x, y)) return HTMAXBUTTON;
  return HTCAPTION;
}

void Win32Window::SetMaxButton(CaptionState state) {
  if (state == max_button_) return;
  max_button_ = state;
  NotifyFrameState();
}

void Win32Window::NotifyFrameState() {
  if (custom_frame_) OnFrameStateChanged(maximized_, active_, max_button_);
}

bool Win32Window::SetCaptionTheme(bool dark, COLORREF background,
                                  COLORREF text, COLORREF border) {
  app_theme_set_ = true;
  app_dark_ = dark;
  caption_color_ = background;
  caption_text_ = text;
  caption_border_ = border;
  UpdateTheme(window_handle_);
  return caption_theme_applied_;
}

void Win32Window::UpdateTheme(HWND const window) {
  if (!window) return;
  DWORD light_mode = 1;
  DWORD size = sizeof(light_mode);
  RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
              kGetPreferredBrightnessRegValue, RRF_RT_REG_DWORD, nullptr,
              &light_mode, &size);
  HIGHCONTRAST contrast = {sizeof(HIGHCONTRAST)};
  SystemParametersInfo(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
  const bool high_contrast = (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;
  BOOL dark = !high_contrast && (app_theme_set_ ? app_dark_ : light_mode == 0);
  const auto dark_result = DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
  // Windows 11 caption and border colors; earlier Windows versions simply
  // retain native defaults. With the custom frame only the border shows.
  const COLORREF system_default = 0xFFFFFFFF;
  const COLORREF background = app_theme_set_ && !high_contrast ? caption_color_ : system_default;
  const COLORREF text = app_theme_set_ && !high_contrast ? caption_text_ : system_default;
  const COLORREF border = app_theme_set_ && !high_contrast ? caption_border_ : system_default;
  const auto caption_result = DwmSetWindowAttribute(window, 35 /* DWMWA_CAPTION_COLOR */, &background, sizeof(background));
  const auto text_result = DwmSetWindowAttribute(window, 36 /* DWMWA_TEXT_COLOR */, &text, sizeof(text));
  const auto border_result = DwmSetWindowAttribute(window, 34 /* DWMWA_BORDER_COLOR */, &border, sizeof(border));
  caption_theme_applied_ = SUCCEEDED(dark_result) && SUCCEEDED(caption_result) &&
      SUCCEEDED(text_result) && SUCCEEDED(border_result);
}
