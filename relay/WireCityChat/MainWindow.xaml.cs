using System.IO;
using System.Windows;
using System.Windows.Input;

namespace WireCityChat;

public partial class MainWindow : Window
{
    private BotSettings _settings = null!;
    private IChatLink _link = null!;
    private ChatBot _bot = null!;
    private StreamWriter? _log;
    private int _visitorsToday;
    private DateTime _visitorsDay = DateTime.Today;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) => await StartAsync();
        Closing += (_, _) =>
        {
            // Off the UI thread to avoid deadlocking on awaited sends.
            try
            {
                Task.Run(async () =>
                {
                    if (_bot is not null && _link.ClientCount != 0 && _link.ClientCount != 1)
                        await _bot.SayGoodbyeAsync();
                    if (_link is not null) await _link.StopAsync();
                }).Wait(TimeSpan.FromSeconds(3));
            }
            catch { /* closing anyway */ }
            _bot?.Dispose();
            _log?.Dispose();
        };
    }

    private async Task StartAsync()
    {
        try
        {
            var args = Environment.GetCommandLineArgs();
            _settings = BotSettings.Load(args.Length > 1 ? args[1] : null);
            Title = $"WIRE CITY CHAT OPERATOR - {_settings.BotName}";
            OpenLog();

            _link = string.IsNullOrWhiteSpace(_settings.RelayUrl)
                ? new EmbeddedLink(_settings)
                : new RemoteLink(_settings);
            _link.Log += line => Post(() => AddStatus(line));
            _link.PacketSeen += OnPacketSeen;
            _link.ClientChange += OnClientChange;
            await _link.StartAsync();

            _bot = new ChatBot(_settings, _link);
            _bot.Status += line => Post(() => { AddStatus("[bot] " + line); UpdateHeader(); });

            UpdateHeader();
            AddStatus(_bot.HasApiKey
                ? $"bot '{_settings.BotName}' active, model {_settings.Model}"
                : "NO API KEY - put it into settings.local.json (ApiKey), bot is silent");
            if (_link is EmbeddedLink)
                AddStatus($"chat page: http://localhost:{_settings.DocsPort}/chat_dev.html");
        }
        catch (Exception e)
        {
            AddStatus("startup failed: " + e.Message);
        }
    }

    private void OnPacketSeen(ulong srcNode, byte[] packet)
    {
        var text = Ipx.PayloadText(packet);
        if (text is null) return;
        if (text.StartsWith("* new caller", StringComparison.Ordinal))
        {
            if (_visitorsDay != DateTime.Today) { _visitorsDay = DateTime.Today; _visitorsToday = 0; }
            _visitorsToday++;
        }
        var self = _bot is not null && srcNode == _bot.Node;
        Post(() => { AddChat(text); UpdateHeader(); });
        WriteLog((self ? "<bot>  " : "<chat> ") + text);
        if (!self && _bot is not null)
            _ = _bot.OnChatLineAsync(text).ContinueWith(
                t => Post(() => AddStatus("[bot] " + t.Exception!.InnerException!.Message)),
                TaskContinuationOptions.OnlyOnFaulted);
    }

    private void OnClientChange(ulong node, bool joined)
    {
        Post(() =>
        {
            AddStatus($"{(joined ? "[+]" : "[-]")} node {Ipx.NodeHex(node)}");
            UpdateHeader();
        });
        _bot?.OnPresenceChange(_link.ClientCount);
        if (joined && _bot is not null && node != _bot.Node)
            _ = _bot.OnPeerJoinedAsync();
    }

    private async void SendButton_Click(object sender, RoutedEventArgs e) => await SendInputAsync();

    private async void InputBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) await SendInputAsync();
    }

    private async Task SendInputAsync()
    {
        var text = InputBox.Text.Trim();
        if (text.Length == 0 || _bot is null) return;
        InputBox.Text = "";
        await _bot.SendManualAsync(text);
    }

    private void UpdateHeader()
    {
        if (_bot is null) return;
        var clients = _link.ClientCount < 0 ? "?" : _link.ClientCount.ToString();
        HeaderText.Text =
            $"room '{_settings.Room}' | clients: {clients} | visitors today: {_visitorsToday} | " +
            $"bot: {_bot.Name} ({_settings.Model}, {(_bot.HasApiKey ? "armed" : "NO KEY")}) | " +
            $"calls: {_bot.CallsThisHour}/{_settings.MaxCallsPerHour}h {_bot.CallsToday}/{_settings.MaxCallsPerDay}d | " +
            $"tokens: {_bot.TotalInputTokens} in / {_bot.TotalOutputTokens} out | " +
            $"~${_bot.EstimatedCostUsd:0.0000}";
    }

    private void AddChat(string line)
    {
        ChatList.Items.Add(line);
        while (ChatList.Items.Count > 500) ChatList.Items.RemoveAt(0);
        ChatList.ScrollIntoView(ChatList.Items[^1]);
    }

    private void AddStatus(string line)
    {
        StatusText.Text = line;
        WriteLog("<sys>  " + line);
    }

    private void OpenLog()
    {
        var dir = Path.Combine(_settings.HomeDir, "logs");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, $"chat-{_settings.BotName}-{DateTime.Now:yyyy-MM-dd}.log");
        _log = new StreamWriter(path, append: true) { AutoFlush = true };
        WriteLog("<sys>  === session started ===");
    }

    private void WriteLog(string line)
    {
        lock (this) _log?.WriteLine($"[{DateTime.Now:HH:mm:ss}] {line}");
    }

    private void Post(Action action) => Dispatcher.BeginInvoke(action);
}
