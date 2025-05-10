@for (.events) |item| {
@html OUTER
<tr class="bg-zinc-600/30 transition-colors even:bg-zinc-700/50">
  <td scope="row" class="text-lg p-1">{{item.user_id}}</td>
  @partial list_event_timestamp(item.from)
  @partial list_event_timestamp(item.to)
  @partial list_event_duration(item.duration)
  <td scope="row" class="text-lg p-1"><p class="rounded-xl p-4 w-fit bg-zinc-800 outline-2 outline-solid outline-yellow-100">{{item.event_type}}</p></td>
  @if (std.mem.eql(u8, try item.object.get("event_type").?.coerce([]const u8), "afk-status"))
  
  @partial list_event_props_afk(item.data)
  
  @else if (std.mem.eql(u8, try item.object.get("event_type").?.coerce([]const u8), "spotify-status"))
  
  @partial list_event_props_media(item.data)

  @else if (std.mem.eql(u8, try item.object.get("event_type").?.coerce([]const u8), "kavita-status"))
  
  @partial list_event_props_kavita(item.data)
  
  @else
  
  
  @partial list_event_props(item.data)

  @end
</tr>
  OUTER
}


@if ($.is_at_end == false)
<tr id="nextPage">
  <td colspan="5">
    <div hx-get="/api/events/get?drop={{.index}}&take=20" hx-swap="outerHTML" hx-target="#nextPage" hx-trigger="intersect"/>
  </td>
<tr>
@end

