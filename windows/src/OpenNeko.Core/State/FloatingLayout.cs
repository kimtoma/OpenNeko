namespace OpenNeko.Core;

/// <summary>
/// Placement of the speech bubble and chat box around the cat, in y-up rects.
/// Mirrors CatBubbleWindow.reposition / CatChatWindow.reposition on macOS.
/// </summary>
public static class FloatingLayout
{
    public const double MinimumBubbleWidth = 132;
    public const double MaximumBubbleWidth = 224;
    public const double MinimumTextHeight = 24;
    public const double MaximumTextHeight = 148;
    public const double ChatWidth = 320;
    private const double EdgeInset = 10;

    /// <summary>How long a bubble stays up: longer text gets extra reading time.</summary>
    public static double BubbleDuration(string text)
    {
        var extraReadTime = Math.Min(3.5, new System.Globalization.StringInfo(text).LengthInTextElements / 90.0);
        return Math.Max(3.5, 4.2 + extraReadTime);
    }

    public static Point BubbleOrigin(Rect catFrame, Size size, Rect visibleFrame, Rect? avoid)
    {
        var origin = new Point(catFrame.MidX - size.Width / 2, catFrame.MaxY - 2);
        if (avoid is Rect avoidFrame) origin = NonOverlappingOrigin(origin, size, avoidFrame, visibleFrame);
        return Clamp(origin, size, visibleFrame);
    }

    public static Point ChatOrigin(Rect catFrame, Size size, Rect visibleFrame) =>
        Clamp(new Point(catFrame.MidX - size.Width / 2, catFrame.MaxY + 8), size, visibleFrame);

    public static Point NonOverlappingOrigin(Point proposed, Size size, Rect avoidFrame, Rect visibleFrame)
    {
        const double gap = 8;
        var padded = avoidFrame.InsetBy(-gap, -gap);
        if (!new Rect(proposed.X, proposed.Y, size.Width, size.Height).Intersects(padded)) return proposed;
        var aboveY = padded.MaxY + gap;
        var belowY = padded.MinY - size.Height - gap;
        double y;
        if (aboveY + size.Height <= visibleFrame.MaxY - EdgeInset) y = aboveY;
        else if (belowY >= visibleFrame.MinY + EdgeInset) y = belowY;
        else
        {
            var aboveOverflow = aboveY + size.Height - (visibleFrame.MaxY - EdgeInset);
            var belowOverflow = visibleFrame.MinY + EdgeInset - belowY;
            y = aboveOverflow <= belowOverflow ? aboveY : belowY;
        }
        return proposed with { Y = y };
    }

    private static Point Clamp(Point origin, Size size, Rect visible) => new(
        Math.Min(Math.Max(origin.X, visible.MinX + EdgeInset), visible.MaxX - size.Width - EdgeInset),
        Math.Min(Math.Max(origin.Y, visible.MinY + EdgeInset), visible.MaxY - size.Height - EdgeInset));
}
