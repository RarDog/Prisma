#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Prefer dark theme for GTK elements
  GtkSettings* gtk_settings = gtk_settings_get_default();
  if (gtk_settings != nullptr) {
    g_object_set(gtk_settings, "gtk-application-prefer-dark-theme", TRUE, nullptr);
  }

  // Determine whether to use a GtkHeaderBar or native window decorations (SSD).
  // In KDE Plasma / KWin, XFCE, Cinnamon, tiling WMs, etc., native decorations
  // integrate seamlessly with the user's desktop theme and avoid thick alien bars.
  // GtkHeaderBar is only suitable when explicitly running under GNOME Shell.
  gboolean use_header_bar = FALSE;

  const gchar* xdg_desktop = g_getenv("XDG_CURRENT_DESKTOP");
  const gchar* kde_session = g_getenv("KDE_FULL_SESSION");
  const gchar* desktop_session = g_getenv("DESKTOP_SESSION");

  gboolean is_kde = (kde_session != nullptr && g_strcmp0(kde_session, "true") == 0);
  if (!is_kde && xdg_desktop != nullptr) {
    g_autofree gchar* upper = g_utf8_strup(xdg_desktop, -1);
    if (g_strstr_len(upper, -1, "KDE") != nullptr || g_strstr_len(upper, -1, "PLASMA") != nullptr) {
      is_kde = TRUE;
    }
  }
  if (!is_kde && desktop_session != nullptr) {
    g_autofree gchar* upper = g_utf8_strup(desktop_session, -1);
    if (g_strstr_len(upper, -1, "KDE") != nullptr || g_strstr_len(upper, -1, "PLASMA") != nullptr) {
      is_kde = TRUE;
    }
  }

  if (!is_kde) {
    if (xdg_desktop != nullptr) {
      g_autofree gchar* upper = g_utf8_strup(xdg_desktop, -1);
      if (g_strstr_len(upper, -1, "GNOME") != nullptr) {
        use_header_bar = TRUE;
      }
    }
#ifdef GDK_WINDOWING_X11
    GdkScreen* screen = gtk_window_get_screen(window);
    if (GDK_IS_X11_SCREEN(screen)) {
      const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
      if (wm_name != nullptr && g_strcmp0(wm_name, "GNOME Shell") == 0) {
        use_header_bar = TRUE;
      } else {
        use_header_bar = FALSE;
      }
    }
#endif
  }

  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Prisma");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_titlebar(window, nullptr);
    gtk_window_set_title(window, "Prisma");
  }

  gtk_window_set_default_icon_name("prisma");
  gtk_window_set_icon_name(window, "prisma");

  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    g_autofree gchar* icon_path = g_build_filename(exe_dir, "prisma.png", nullptr);
    if (!g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      g_clear_pointer(&icon_path, g_free);
      icon_path = g_build_filename(
          exe_dir, "data", "flutter_assets", "assets", "icon", "app_icon_rounded.png", nullptr);
    }
    if (icon_path != nullptr && g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      GError* pix_err = nullptr;
      GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(icon_path, &pix_err);
      if (pixbuf != nullptr) {
        gtk_window_set_icon(window, pixbuf);
        gtk_window_set_default_icon(pixbuf);
        g_object_unref(pixbuf);
      }
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
      gtk_window_set_default_icon_from_file(icon_path, nullptr);
    }
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
