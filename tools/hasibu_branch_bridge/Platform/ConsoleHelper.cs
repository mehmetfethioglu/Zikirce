using System.Runtime.InteropServices;
using System.Text;

namespace HasibuBranchBridge.Platform;

/// <summary>
/// WinExe hedefinde yalnızca etkileşimli/CLI komutları (--setup, --test, --help)
/// sırasında konsolu açar veya üst konsola bağlanır; varsayılan arka plan modunda pencere açmaz.
/// </summary>
public static class ConsoleHelper
{
    private const int AttachParentProcess = -1;

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AttachConsole(int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AllocConsole();

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    public static void EnsureInteractiveConsole()
    {
        if (Console.IsOutputRedirected && Console.IsErrorRedirected)
        {
            return;
        }

        var attached = false;
        if (GetConsoleWindow() == IntPtr.Zero)
        {
            attached = AttachConsole(AttachParentProcess);
            if (!attached && !Console.IsOutputRedirected)
            {
                attached = AllocConsole();
            }
        }

        if (attached)
        {
            try
            {
                Console.OutputEncoding = Encoding.UTF8;
                Console.InputEncoding = Encoding.UTF8;
            }
            catch
            {
                // Yoksay
            }

            if (!Console.IsOutputRedirected)
            {
                var stdout = new StreamWriter(Console.OpenStandardOutput(), Console.OutputEncoding) { AutoFlush = true };
                Console.SetOut(stdout);
            }
            if (!Console.IsErrorRedirected)
            {
                var stderr = new StreamWriter(Console.OpenStandardError(), Console.OutputEncoding) { AutoFlush = true };
                Console.SetError(stderr);
            }
            if (!Console.IsInputRedirected)
            {
                var stdin = new StreamReader(Console.OpenStandardInput(), Console.InputEncoding);
                Console.SetIn(stdin);
            }
        }
    }
}
