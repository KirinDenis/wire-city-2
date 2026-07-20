// The chat persona: watches the room, decides when to speak, calls the
// Claude API, and broadcasts replies as IPX chat lines. Pacing is
// deliberately slow: hourly/daily caps, a minimum interval between any
// two replies, and jitter - so two bots hold an unhurried conversation
// and nobody can talk the budget away.

using System.IO;
using System.Text;
using Anthropic;
using Anthropic.Models.Messages;

namespace WireCityChat;

public sealed class ChatBot : IDisposable
{
    private readonly BotSettings _settings;
    private readonly IChatLink _link;
    private readonly AnthropicClient? _client;
    private readonly List<string> _buffer = [];
    private readonly Queue<DateTime> _callTimes = new();
    private readonly SemaphoreSlim _replyLock = new(1, 1);
    private readonly object _stateLock = new();
    private readonly Timer _initiativeTimer;

    private int _messagesSinceReply;
    private DateTime _lastReplyAt = DateTime.MinValue;
    private DateTime _lastBotLineAt = DateTime.MinValue;
    private DateTime _lastGreetAt = DateTime.MinValue;
    private DateTime _lastInitiativeAt = DateTime.MinValue;
    private DateTime _lastIncomingAt = DateTime.MinValue;
    private DateTime _lastHumanLineAt = DateTime.MinValue;
    private DateTime _presenceSince = DateTime.MinValue;
    private readonly string[] _knownBots;
    private DateTime _statsDay = DateTime.Today;
    private int _callsToday;

    public long TotalInputTokens { get; private set; }
    public long TotalOutputTokens { get; private set; }
    public int CallsToday { get { lock (_stateLock) return _callsToday; } }
    public int CallsThisHour { get { lock (_stateLock) { PurgeCallTimes(); return _callTimes.Count; } } }
    public bool HasApiKey => _client is not null;
    public ulong Node => _link.BotNode;
    public string Name => _settings.BotName;

    public event Action<string>? Status;

    // input $/MTok, output $/MTok - for the UI cost estimate only
    private static readonly Dictionary<string, (double In, double Out)> Prices = new()
    {
        ["claude-haiku-4-5"] = (1, 5),
        ["claude-sonnet-5"] = (3, 15),
        ["claude-sonnet-4-6"] = (3, 15),
        ["claude-opus-4-8"] = (5, 25),
        ["claude-fable-5"] = (10, 50),
    };

    public double EstimatedCostUsd
    {
        get
        {
            var price = Prices.TryGetValue(_settings.Model, out var p) ? p : (In: 5.0, Out: 25.0);
            return (TotalInputTokens * price.In + TotalOutputTokens * price.Out) / 1_000_000.0;
        }
    }

    public ChatBot(BotSettings settings, IChatLink link)
    {
        _settings = settings;
        _link = link;
        _knownBots = settings.KnownBots.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (!string.IsNullOrWhiteSpace(settings.ApiKey))
            _client = new AnthropicClient { ApiKey = settings.ApiKey };
        _initiativeTimer = new Timer(_ => _ = TryInitiativeAsync(), null,
            TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
    }

    public void Dispose() => _initiativeTimer.Dispose();

    private bool IsBotLine(string line) =>
        line.StartsWith("  ", StringComparison.Ordinal) // bot continuation lines
        || _knownBots.Any(b => line.StartsWith(b + ":", StringComparison.OrdinalIgnoreCase));

    private bool HumanRecently()
    {
        lock (_stateLock)
            return DateTime.UtcNow - _lastHumanLineAt
                < TimeSpan.FromMinutes(_settings.HumanActivityWindowMinutes);
    }

    public async Task OnChatLineAsync(string line)
    {
        var fromBot = IsBotLine(line);
        lock (_stateLock)
        {
            _buffer.Add(line);
            while (_buffer.Count > _settings.ContextLines) _buffer.RemoveAt(0);
            if (!fromBot) _messagesSinceReply++; // only humans drive the chime
            _lastIncomingAt = DateTime.UtcNow;
            if (!fromBot) _lastHumanLineAt = DateTime.UtcNow;
            if (_presenceSince == DateTime.MinValue) _presenceSince = DateTime.UtcNow;
        }
        if (_client is null) return;

        var addressed = line.Contains(_settings.BotName, StringComparison.OrdinalIgnoreCase);
        if (fromBot)
        {
            // Visitors first: bots answer each other only when addressed,
            // rarely, and never in an empty room.
            if (!addressed || !HumanRecently()) return;
            if (DateTime.UtcNow - _lastReplyAt < TimeSpan.FromMinutes(_settings.BotToBotCooldownMinutes)) return;
        }
        else
        {
            bool chime;
            lock (_stateLock) chime = _messagesSinceReply >= _settings.ChimeEveryNMessages;
            if (!addressed && !chime) return;
        }

        // Length-match the conversation: short small talk earns a short
        // reply and a small token budget; only a substantial question
        // unlocks the full reply size.
        var text = line.Contains(": ") ? line[(line.IndexOf(": ") + 2)..] : line;
        // "code" requests are never small talk, however short the ask.
        var brief = text.Length < 40 && !text.Contains("code", StringComparison.OrdinalIgnoreCase);
        await ReplyAsync(
            "Continue the conversation naturally. If someone addressed you by name, answer them. " +
            "Human visitors always come before fellow regulars." +
            (brief ? " The last message is short small talk: answer with a few words on ONE line, " +
                     "or ask one short clarifying question. Do not elaborate." : ""),
            brief);
    }

    public void OnPresenceChange(int clientCount)
    {
        lock (_stateLock)
        {
            if (clientCount > 1 && _presenceSince == DateTime.MinValue)
                _presenceSince = DateTime.UtcNow;
            else if (clientCount <= 1)
                _presenceSince = DateTime.MinValue;
        }
    }

    // Canned sysop-style greeting - a human says "hi", not a paragraph,
    // and it costs zero API calls. Sometimes stays silent on purpose:
    // nothing is more human in a chat than not reacting instantly.
    public async Task OnPeerJoinedAsync()
    {
        if (_client is null) return;
        // Give the DOS side a moment to boot the terminal before greeting.
        await Task.Delay(TimeSpan.FromSeconds(8));
        if (DateTime.UtcNow - _lastGreetAt < TimeSpan.FromSeconds(_settings.GreetCooldownSeconds)) return;
        if (Random.Shared.Next(100) < 40) return; // lurk bias
        _lastGreetAt = DateTime.UtcNow;
        string[] greetings = ["hi", "yo", "sup", "hi there", "evening", "o/"];
        await Task.Delay(Random.Shared.Next(1500, 6000));
        await SendLinesAsync([greetings[Random.Shared.Next(greetings.Length)]]);
    }

    // Someone has been around for a while and the bot is idle: go make friends.
    private async Task TryInitiativeAsync()
    {
        if (_client is null) return;
        if (!HumanRecently()) return; // empty room or bots-only: stay silent
        var now = DateTime.UtcNow;
        bool someoneAround;
        lock (_stateLock)
        {
            someoneAround = _link.ClientCount > 1
                || (_link.ClientCount < 0 && now - _lastIncomingAt < TimeSpan.FromMinutes(10));
            if (!someoneAround || _presenceSince == DateTime.MinValue) return;
            if (now - _presenceSince < TimeSpan.FromMinutes(_settings.IdleInitiativeMinutes)) return;
            if (now - _lastBotLineAt < TimeSpan.FromMinutes(_settings.IdleInitiativeMinutes)) return;
            if (now - _lastInitiativeAt < TimeSpan.FromMinutes(_settings.InitiativeCooldownMinutes)) return;
            _lastInitiativeAt = now;
        }
        await ReplyAsync(
            "People are around but the conversation has stalled (or never started). " +
            "Take the initiative in character: introduce yourself if you have not yet, " +
            "or ask what people are working on, and gently steer toward your favorite " +
            "topics - legacy software, OWLOS, how few real specialists are left.");
    }

    public Task SendManualAsync(string text) => SendLinesAsync(SplitLines(text));

    // Canned farewell on app shutdown - no API call, stays in character.
    public Task SayGoodbyeAsync()
    {
        string[] lines = ["brb", "gtg, brb later", "afk for a bit, cya", "brb, they are rebooting me.. i mean the machine"];
        var pick = lines[Random.Shared.Next(lines.Length)];
        return SendLinesAsync([pick]);
    }

    private async Task ReplyAsync(string instruction, bool brief = false)
    {
        if (_client is null) return;
        if (!await _replyLock.WaitAsync(0)) return; // one reply in flight at a time
        try
        {
            // Pace: never two replies closer than MinSecondsBetweenReplies,
            // plus a small human-feeling jitter.
            var since = DateTime.UtcNow - _lastReplyAt;
            var minGap = TimeSpan.FromSeconds(_settings.MinSecondsBetweenReplies);
            if (since < minGap) await Task.Delay(minGap - since);
            await Task.Delay(Random.Shared.Next(2000, 7000));

            lock (_stateLock)
            {
                if (_statsDay != DateTime.Today) { _statsDay = DateTime.Today; _callsToday = 0; }
                PurgeCallTimes();
                if (_callsToday >= _settings.MaxCallsPerDay)
                {
                    Status?.Invoke("daily call cap reached - bot is silent until tomorrow");
                    return;
                }
                if (_callTimes.Count >= _settings.MaxCallsPerHour)
                {
                    Status?.Invoke("hourly call cap reached - bot is resting");
                    return;
                }
                _callsToday++;
                _callTimes.Enqueue(DateTime.UtcNow);
            }

            string chatText;
            lock (_stateLock) chatText = _buffer.Count > 0 ? string.Join("\n", _buffer) : "(no messages yet)";

            var prompt =
                $"Recent chat lines, oldest first (lines starting with '{_settings.BotName}:' are yours):\n" +
                $"{chatText}\n\n{instruction}\n" +
                $"Reply with at most {_settings.MaxReplyLines} short lines, each under 68 characters, " +
                "plain ASCII. Do not prefix your own name; it is added automatically. " +
                "If there is nothing worth saying, reply with exactly: (silent)";

            var response = await _client.Messages.Create(new MessageCreateParams
            {
                Model = _settings.Model,
                MaxTokens = brief ? Math.Min(100, _settings.MaxTokensPerReply) : _settings.MaxTokensPerReply,
                System = new List<TextBlockParam>
                {
                    new() { Text = _settings.Persona.Replace("{NAME}", _settings.BotName) },
                },
                Messages = [new() { Role = Role.User, Content = prompt }],
            });

            TotalInputTokens += response.Usage.InputTokens;
            TotalOutputTokens += response.Usage.OutputTokens;
            Status?.Invoke($"api call ok: {response.Usage.InputTokens} in / {response.Usage.OutputTokens} out");

            var text = string.Concat(
                response.Content.Select(b => b.Value).OfType<TextBlock>().Select(t => t.Text));
            if (string.IsNullOrWhiteSpace(text) || text.Contains("(silent)")) return;

            _lastReplyAt = DateTime.UtcNow;
            lock (_stateLock) _messagesSinceReply = 0;
            await SendLinesAsync(SplitLines(text));
        }
        catch (Exception e)
        {
            Status?.Invoke($"api error: {e.Message}");
        }
        finally
        {
            _replyLock.Release();
        }
    }

    private void PurgeCallTimes()
    {
        var cutoff = DateTime.UtcNow - TimeSpan.FromHours(1);
        while (_callTimes.Count > 0 && _callTimes.Peek() < cutoff) _callTimes.Dequeue();
    }

    private async Task SendLinesAsync(IReadOnlyList<string> lines)
    {
        _lastBotLineAt = DateTime.UtcNow;
        for (var i = 0; i < lines.Count; i++)
        {
            var prefix = i == 0 ? $"{_settings.BotName}: " : "  ";
            var payload = Ipx.TextPayload(prefix + lines[i]);
            await _link.SendBroadcastAsync(Ipx.ChatSocket, payload);
            await Task.Delay(250);
        }
    }

    private List<string> SplitLines(string text)
    {
        const int maxLen = 68;
        var result = new List<string>();
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0) continue;
            while (line.Length > maxLen)
            {
                var cut = line.LastIndexOf(' ', maxLen);
                if (cut < maxLen / 2) cut = maxLen;
                result.Add(line[..cut].TrimEnd());
                line = line[cut..].TrimStart();
            }
            if (line.Length > 0) result.Add(line);
            if (result.Count >= _settings.MaxReplyLines) break;
        }
        if (result.Count > _settings.MaxReplyLines)
            result.RemoveRange(_settings.MaxReplyLines, result.Count - _settings.MaxReplyLines);
        return result;
    }
}
