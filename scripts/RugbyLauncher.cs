using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class RugbyLauncher
{
    private const string Title = "Rugby World Cup 2011";

    [STAThread]
    private static int Main()
    {
        try
        {
            if (Process.GetProcessesByName("rugby2011").Length != 0 ||
                Process.GetProcessesByName("xenia_canary").Length != 0)
            {
                MessageBox.Show("Cerrá la sesión del juego que ya está abierta.", Title,
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return 1;
            }

            string root = AppDomain.CurrentDomain.BaseDirectory;
            string mingwBuild = Path.Combine(root, "build", "mingw-playable");
            bool useMingw = File.Exists(Path.Combine(mingwBuild, "rugby2011.exe"));
            string build = useMingw ? mingwBuild : Path.Combine(root, "build", "port-shadow-integer-fetch");
            string executable = Path.Combine(build, "rugby2011.exe");
            string data = Path.Combine(root, "work");
            string game = useMingw ? Path.Combine(root, "original", "game") : Path.Combine(data, "game");
            string saves = Path.Combine(data, "saves");
            string cache = Path.Combine(data, useMingw ? "cache-mingw-r16-v1" : "cache-integer-r16-v1");
            string updates = Path.Combine(data, "updates");
            string metadata = Path.Combine(data, "metadata");
            string logs = Path.Combine(data, "logs");

            string[] libraries = useMingw
                ? new[] { "rexgpu-xenos.dll", "librexruntime.dll", "libc++.dll", "libunwind.dll" }
                : new[] { "rexgpu-xenosrd.dll", "rexruntimerd.dll", "TracyClientrd.dll" };
            foreach (string library in libraries)
            {
                RequireFile(Path.Combine(build, library));
            }
            RequireFile(executable);
            RequireFile(Path.Combine(game, "default.xex"));

            foreach (string directory in new[] { saves, cache, updates, metadata, logs })
                Directory.CreateDirectory(directory);

            var startInfo = new ProcessStartInfo
            {
                FileName = executable,
                WorkingDirectory = root,
                UseShellExecute = false,
                Arguments = "--gpu_plugin=xenos --no-async_shader_compilation --no-fullscreen" +
                    " --log_level=info --log_flush_interval=1" +
                    PathOption("game_data_root", game) +
                    PathOption("user_data_root", saves) +
                    PathOption("cache_root", cache) +
                    PathOption("update_data_root", updates) +
                    PathOption("metadata_root", metadata) +
                    PathOption("log_file", Path.Combine(logs, "rugby2011.log"))
            };
            using (Process.Start(startInfo)) { }
            return 0;
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static void RequireFile(string path)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException("Falta un archivo del juego:" + Environment.NewLine + path);
    }

    private static string PathOption(string name, string path)
    {
        return " --" + name + "=\"" + path + "\"";
    }
}
