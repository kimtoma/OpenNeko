using System;
using System.IO;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace OpenNeko.Windows.UI;

/// <summary>The app icon, loaded from Assets\openneko.ico next to the executable.</summary>
internal static class AppIcon
{
    private static string FilePath => Path.Combine(AppContext.BaseDirectory, "Assets", "openneko.ico");

    /// <summary>For WPF window title bars; null if the file is missing.</summary>
    public static ImageSource? Image()
    {
        try
        {
            if (!File.Exists(FilePath)) return null;
            var image = new BitmapImage();
            image.BeginInit();
            image.UriSource = new Uri(FilePath);
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.EndInit();
            image.Freeze();
            return image;
        }
        catch (Exception e) when (e is IOException or NotSupportedException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>For the tray icon; falls back to the generic application icon.</summary>
    public static System.Drawing.Icon TrayIcon()
    {
        try
        {
            return File.Exists(FilePath) ? new System.Drawing.Icon(FilePath) : System.Drawing.SystemIcons.Application;
        }
        catch (Exception e) when (e is IOException or ArgumentException or UnauthorizedAccessException)
        {
            return System.Drawing.SystemIcons.Application;
        }
    }
}
