#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>
#include <vector>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  bool SetCaptionTheme(bool dark, COLORREF background, COLORREF text, COLORREF border);

  // A rectangle in the Flutter view's logical pixels.
  struct LogicalRect {
    double left, top, right, bottom;
    bool Contains(double x, double y) const {
      return x >= left && x < right && y >= top && y < bottom;
    }
  };

  // Removes the native caption; the app draws its own title bar. The left,
  // right and bottom frame stay native (resize borders, shadow, corners).
  bool EnableCustomFrame();

  // The app's title bar: its height, its maximize button and its
  // interactive controls. The rest of the bar is caption (drag) space.
  void SetCaptionRegions(double height, const LogicalRect& maximize,
                         std::vector<LogicalRect> interactive);

  // The maximize button's pointer state, owned here so Windows can show
  // the Snap Layouts flyout.
  enum class CaptionState { kNone = 0, kHover = 1, kPressed = 2 };

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

  // Called when the window's maximized or active state, or the maximize
  // button's state, changes while the custom frame is on.
  virtual void OnFrameStateChanged(bool maximized, bool active,
                                   CaptionState max_button) {}

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Hosted content (the Flutter view) is transparent to hit testing over the
  // caption, so this window answers for it.
  static LRESULT CALLBACK ContentProc(HWND window, UINT message, WPARAM wparam,
                                      LPARAM lparam, UINT_PTR id,
                                      DWORD_PTR data) noexcept;

  // Hit test for the custom frame, from a point in screen coordinates.
  LRESULT FrameHitTest(POINT screen) const;

  // The top resize band, also the padding a maximized window hides.
  int ResizeBorderHeight() const;

  void SetMaxButton(CaptionState state);
  void NotifyFrameState();
  bool custom_frame_ = false;
  bool maximized_ = false, active_ = true, max_pressed_ = false;
  CaptionState max_button_ = CaptionState::kNone;
  double caption_height_ = 0;
  LogicalRect max_rect_{0, 0, 0, 0};
  std::vector<LogicalRect> interactive_;

  // Update the window frame's theme to match the system theme.
  void UpdateTheme(HWND const window);
  bool caption_theme_applied_ = false;
  bool app_theme_set_ = false;
  bool app_dark_ = false;
  COLORREF caption_color_ = 0, caption_text_ = 0, caption_border_ = 0;

  bool quit_on_close_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
