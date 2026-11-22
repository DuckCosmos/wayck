using System.Text.Json.Serialization;

namespace Wayck.Backend;

[JsonSerializable(typeof(List<AppData>))]
[JsonSerializable(typeof(List<ClipboardItem>))]
[JsonSerializable(typeof(VersionInfo))]
[JsonSerializable(typeof(MonitorData))]
internal partial class WayckJsonContext : JsonSerializerContext { }
