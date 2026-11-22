namespace Wayck.Backend;

internal sealed record ClipboardItem(string id, string content, bool is_image, string? path);
