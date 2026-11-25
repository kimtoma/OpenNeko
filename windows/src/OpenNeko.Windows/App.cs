using System;
using System.Threading;
using System.Windows;
using OpenNeko.Core;
using OpenNeko.Windows.Services;

namespace OpenNeko.Windows;

/// <summary>Entry point. Code-only WPF application (no XAML): the app lives in the tray.</summary>
internal sealed class App : Application
{
    private AppController? _controller;

    [STAThread]
    public static int Main()
    {
        var port = StateBridgePort.Resolve(ChatProviders.EnvironmentMap());
        // One instance per bridge port, so OPENNEKO_PORT=48801 can run a second cat.
        using var mutex = new Mutex(initiallyOwned: true, $"Local\\OpenNeko-{port}", out var createdNew);
        if (!createdNew)
        {
            var lang = AppLanguage.Resolved(null, System.Globalization.CultureInfo.CurrentUICulture.Name);
            MessageBox.Show(WindowsCopy.Get(WindowsCopyKey.AlreadyRunning, lang), "OpenNeko", MessageBoxButton.OK, MessageBoxImage.Information);
            return 0;
        }
        var app = new App { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        return app.Run();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _controller = new AppController(Dispatcher);
        _controller.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _controller?.Dispose();
        base.OnExit(e);
    }
}
