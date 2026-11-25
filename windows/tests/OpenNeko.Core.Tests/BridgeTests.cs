using System.Text;
using OpenNeko.Core;

namespace OpenNeko.Core.Tests;

public class StateBridgeRequestTests
{
    private static StateBridgeEvent Parse(string json) => StateBridgeRequest.Parse(Encoding.UTF8.GetBytes(json));

    [Fact]
    public void DefaultsSourceToAgent()
    {
        var evt = Parse("{\"state\":\"coding\"}");
        Assert.Equal(CatState.Coding, evt.State);
        Assert.Equal("agent", evt.Source);
        Assert.Null(evt.Message);
    }

    [Fact]
    public void MapsElectronAliases()
    {
        Assert.Equal(CatState.Hover, Parse("{\"state\":\"waiting\",\"source\":\"hook\"}").State);
        Assert.Equal(CatState.Click, Parse("{\"state\":\"clicked\"}").State);
    }

    [Fact]
    public void TruncatesSourceAndMessage()
    {
        var evt = Parse($"{{\"state\":\"success\",\"source\":\"{new string('s', 50)}\",\"message\":\"{new string('m', 140)}\"}}");
        Assert.Equal(40, evt.Source.Length);
        Assert.Equal(120, evt.Message!.Length);
    }

    [Fact]
    public void EmptyMessageBecomesNull() => Assert.Null(Parse("{\"state\":\"idle\",\"message\":\"\"}").Message);

    [Theory]
    [InlineData("{\"state\":\"ghost\"}", "invalidState")]
    [InlineData("{}", "invalidState")]
    [InlineData("not json", "invalidPayload")]
    [InlineData("{\"state\":3}", "invalidPayload")]
    [InlineData("[1]", "invalidPayload")]
    public void RejectsBadPayloads(string json, string reason) =>
        Assert.Equal(reason, Assert.Throws<StateBridgeRequestException>(() => Parse(json)).Reason);
}

public class StateBridgeHttpTests
{
    [Fact]
    public void ParsesCompleteRequestWithBody()
    {
        var body = "{\"state\":\"coding\"}";
        var raw = $"POST /state HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: {body.Length}\r\n\r\n{body}";
        var request = StateBridgeHttpRequest.TryParse(Encoding.UTF8.GetBytes(raw))!;
        Assert.Equal("POST", request.Method);
        Assert.Equal("/state", request.Path);
        Assert.Equal(body, Encoding.UTF8.GetString(request.Body));
    }

    [Fact]
    public void ReturnsNullWhileIncompleteOrOversized()
    {
        Assert.Null(StateBridgeHttpRequest.TryParse("GET /health HTTP/1.1\r\n"u8));
        Assert.Null(StateBridgeHttpRequest.TryParse("POST /state HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc"u8));
        Assert.Null(StateBridgeHttpRequest.TryParse(Encoding.UTF8.GetBytes("POST /state HTTP/1.1\r\nContent-Length: 5000\r\n\r\n")));
    }

    [Fact]
    public void ResponseSerializesHeaders()
    {
        var text = Encoding.UTF8.GetString(StateBridgeHttpResponse.Ok("ok").ToBytes());
        Assert.Equal("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok", text);
    }

    [Fact]
    public void PortHonorsEnvironmentOverride()
    {
        Assert.Equal(48801, StateBridgePort.Resolve(new Dictionary<string, string?> { ["OPENNEKO_PORT"] = "48801" }));
        Assert.Equal(48800, StateBridgePort.Resolve(new Dictionary<string, string?> { ["OPENNEKO_PORT"] = "nope" }));
        Assert.Equal(48800, StateBridgePort.Resolve(new Dictionary<string, string?>()));
    }

    [Theory]
    [InlineData("POST", "/state", StateBridgeRoute.PostState)]
    [InlineData("GET", "/health", StateBridgeRoute.Health)]
    [InlineData("GET", "/pos", StateBridgeRoute.Position)]
    [InlineData("GET", "/debug/position", StateBridgeRoute.Position)]
    [InlineData("GET", "/state", StateBridgeRoute.NotFound)]
    public void RoutesMatchMacServer(string method, string path, StateBridgeRoute route) =>
        Assert.Equal(route, StateBridgeRouter.Route(method, path));

    [Fact]
    public void AnimJsonShape() =>
        Assert.Equal("{\"anim\":\"typing\",\"keydownCount\":7}", StateBridgeRouter.AnimJson(CatState.Typing, 7));
}

public class BubbleCopyTests
{
    [Fact]
    public void BridgeMessageWinsAndIsTruncated()
    {
        var evt = new StateBridgeEvent(CatState.Coding, "agent", new string('x', 60));
        Assert.Equal(48, StateBubbleText.Text(evt, "en")!.Length);
    }

    [Fact]
    public void DefaultStateTextIsLocalized()
    {
        var evt = new StateBridgeEvent(CatState.Coding, "agent", null);
        Assert.Equal("Coding, nya~", StateBubbleText.Text(evt, "en"));
        Assert.Equal("코딩 중이다냥", StateBubbleText.Text(evt, null));
        Assert.Equal("コーディング中にゃ", StateBubbleText.Text(evt, "ja-JP"));
        Assert.Null(StateBubbleText.Text(new StateBridgeEvent(CatState.Idle, "agent", null), "en"));
    }

    [Theory]
    [InlineData("Hello there!", "en", "Hello there, nya~!")]
    [InlineData("Already nya~", "en", "Already nya~")]
    [InlineData("좋아요.", "ko", "좋아요냥.")]
    [InlineData("いいね", "ja", "いいねにゃ")]
    [InlineData("好的。", "zh", "好的喵。")]
    [InlineData("  ", "en", "")]
    public void StyledReplyAppendsCatSuffixOnce(string reply, string lang, string expected) =>
        Assert.Equal(expected, NekoBubbleCopy.StyledChatReply(reply, lang));

    [Fact]
    public void EveryCopyHasFourLanguages()
    {
        var langs = new[] { "ko", "en", "ja", "zh" };
        Assert.Equal(4, langs.Select(NekoBubbleCopy.ChatPlaceholder).Distinct().Count());
        Assert.Equal(4, langs.Select(l => NekoBubbleCopy.AgentWorking("Claude", l)).Distinct().Count());
        foreach (var key in Enum.GetValues<WindowsCopyKey>())
        {
            foreach (var lang in langs) Assert.False(string.IsNullOrWhiteSpace(WindowsCopy.Get(key, lang)));
            Assert.NotEqual(key.ToString(), WindowsCopy.Get(key, "ko"));
        }
        foreach (var state in CatStateExtensions.All)
        {
            Assert.All(langs, l => Assert.False(string.IsNullOrWhiteSpace(CatStateMenu.Title(state, l))));
            Assert.NotEqual(CatStateMenu.Title(state, "ko"), CatStateMenu.Title(state, "en"));
        }
    }

    [Fact]
    public void LanguageNormalization()
    {
        Assert.Equal("zh", AppLanguage.Normalized("zh_Hant_TW"));
        Assert.Equal("ko", AppLanguage.Normalized(" KO-kr "));
        Assert.Null(AppLanguage.Normalized("fr"));
        Assert.Equal("ja", AppLanguage.Resolved(null, "ja-JP"));
        Assert.Equal("en", AppLanguage.Resolved(null, "fr-FR"));
        Assert.Equal("ko", AppLanguage.Resolved("ko", "fr-FR"));
    }
}
