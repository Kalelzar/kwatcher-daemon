<article class="bg-zinc-800 rounded-xl p-4 shadow-xl shadow-zinc-900 relative w-full">
  <h2 class="text-2xl">Events</h2>
  <div class="border-t border-white mt-4 pt-4">
    <div class="rounded-xl p-2 bg-zinc-700 inset-shadow-sm inset-shadow-zinc-600">
      <table class="container">
        <thead>
          <tr>
            <th scope="column" class="bg-zinc-700 p-1">User</th>
            <th scope="column" class="bg-zinc-700 p-1">From</th>
            <th scope="column" class="bg-zinc-700 p-1">To</th>
            <th scope="column" class="bg-zinc-700 p-1">Duration</th>
            <th scope="column" class="bg-zinc-700 p-1">Event</th>
            <th scope="column" class="bg-zinc-700 p-1">Data</th>
          </tr>
        </thead>
        <tbody>
          <tr id="nextPage">
            <td colspan="3">
              <div hx-get="/api/events/get?drop=0&take=20" hx-swap="outerHTML" hx-target="#nextPage" hx-trigger="load"/>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</article>
