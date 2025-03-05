@for (.events) |item| {
@html OUTER
<tr>
  <td scope="row" class="bg-zinc-700 text-lg p-1">{{item.user_id}}</td>
  @partial list_event_timestamp(item.from)
  @partial list_event_timestamp(item.to)
  @partial list_event_duration(item.duration)
  <td scope="row" class="bg-zinc-700 text-lg p-1">{{item.event_type}}</td>
  @partial list_event_props(item.data)
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

