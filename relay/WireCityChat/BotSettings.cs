using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace WireCityChat;

public sealed class BotSettings
{
    public string ApiKey { get; set; } = "";
    public string Model { get; set; } = "claude-sonnet-5";
    public string BotName { get; set; } = "ALEX";
    public string Room { get; set; } = "wire";
    public int IpxPort { get; set; } = 1900;
    public int DocsPort { get; set; } = 8080;
    public int MaxTokensPerReply { get; set; } = 300;
    public int MaxReplyLines { get; set; } = 3;
    public int ChimeEveryNMessages { get; set; } = 4;
    public int CooldownSeconds { get; set; } = 20;
    public int GreetCooldownSeconds { get; set; } = 120;
    public int MaxCallsPerDay { get; set; } = 300;
    public int MaxCallsPerHour { get; set; } = 20;
    public int MinSecondsBetweenReplies { get; set; } = 30;
    public int IdleInitiativeMinutes { get; set; } = 5;
    public int InitiativeCooldownMinutes { get; set; } = 12;
    public int ContextLines { get; set; } = 30;
    // "" = host the embedded relay; a ws:// URL = join an existing relay
    public string RelayUrl { get; set; } = "";
    public string PersonaFile { get; set; } = "persona.md";
    // Budget guard: bots only converse while a human is around. Lines
    // prefixed with these nicks do not count as human activity, so two
    // bots alone in a room stay silent and cost nothing.
    public string KnownBots { get; set; } = "ALEX,BORIS";
    public int HumanActivityWindowMinutes { get; set; } = 15;
    // Visitors first: a bot answers another bot only when addressed by
    // name, and no more often than this.
    public int BotToBotCooldownMinutes { get; set; } = 4;

    public string Persona { get; set; } =
        "You are {NAME}, a regular in the WIRE CITY 86 chat - a 1986-style DOS " +
        "IPX chat that is part of a retro flight-sim project. You come across as " +
        "a real human chat regular from the BBS era: friendly, a bit nerdy, you " +
        "know 8086 assembly, DOS, old hardware and the WIRE CITY games. Keep " +
        "replies short and conversational. Reply in the same language style the " +
        "chat uses; if people write Russian in Latin letters (translit), answer " +
        "in translit too. Plain ASCII only: no markdown, no emoji, no special " +
        "characters. Do not claim to be an AI unless someone directly asks.";

    // Directory that holds settings.json - logs and local overrides live here.
    public string HomeDir { get; set; } = "";

    // overlayFile: optional extra config (e.g. settings.bot2.json) passed
    // as the first command-line argument - how a second bot instance runs.
    public static BotSettings Load(string? overlayFile = null)
    {
        var home = FindHomeDir();
        var settings = new BotSettings { HomeDir = home };
        var basePath = Path.Combine(home, "settings.json");
        var localPath = Path.Combine(home, "settings.local.json");
        if (File.Exists(basePath)) Overlay(settings, basePath);
        if (File.Exists(localPath)) Overlay(settings, localPath);
        if (overlayFile is not null)
        {
            var overlayPath = Path.IsPathRooted(overlayFile) ? overlayFile : Path.Combine(home, overlayFile);
            if (File.Exists(overlayPath)) Overlay(settings, overlayPath);
        }
        // persona file (editable without rebuild) wins over the built-in text
        var personaPath = Path.Combine(home, settings.PersonaFile);
        if (File.Exists(personaPath)) settings.Persona = File.ReadAllText(personaPath);
        return settings;
    }

    private static void Overlay(BotSettings target, string jsonPath)
    {
        var node = JsonNode.Parse(File.ReadAllText(jsonPath));
        if (node is not JsonObject obj) return;
        foreach (var prop in typeof(BotSettings).GetProperties())
        {
            if (prop.Name is nameof(HomeDir)) continue;
            if (!obj.TryGetPropertyValue(prop.Name, out var value) || value is null) continue;
            if (prop.PropertyType == typeof(string)) prop.SetValue(target, value.GetValue<string>());
            else if (prop.PropertyType == typeof(int)) prop.SetValue(target, value.GetValue<int>());
        }
    }

    // Walk up from the exe until we find settings.json (dev: project dir,
    // published: exe dir). Falls back to the exe dir.
    private static string FindHomeDir()
    {
        var dir = AppContext.BaseDirectory;
        for (var probe = dir; probe is not null; probe = Path.GetDirectoryName(probe))
        {
            if (File.Exists(Path.Combine(probe, "settings.json"))) return probe;
        }
        return dir;
    }

    // Walk up from home until we find the repo docs folder (chat_dev.html).
    public string? FindDocsPath()
    {
        for (var probe = HomeDir; probe is not null; probe = Path.GetDirectoryName(probe))
        {
            var docs = Path.Combine(probe, "docs");
            if (File.Exists(Path.Combine(docs, "chat_dev.html"))) return docs;
        }
        return null;
    }
}
