using System.Text.Json.Serialization;

namespace Wayck.Backend;

internal record App(string Nome, [property: JsonPropertyName("icone_path")] string IconePath, string Exec);
internal record Clip(string ID, string Content, [property: JsonPropertyName("is_image")] bool IsImage, string Path);
internal record VersionInfo(string Local, string Remote, bool Available);

