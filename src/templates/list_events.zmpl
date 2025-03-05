@for (.events) |item| {
@html OUTER
<tr>
  @partial list_event_timestamp(item.from)
  @partial list_event_timestamp(item.to)
  <td scope="row" class="bg-zinc-700 text-lg p-1">{{item.event_type}}</td>
</tr>
  OUTER
}

<tr id="nextPage">
  <td colspan="3">
    <div hx-get="/api/events/get?drop={{.index}}&take=20" hx-swap="outerHTML" hx-target="#nextPage" hx-trigger="intersect"/>
  </td>
<tr>
