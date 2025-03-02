<article class="bg-zinc-800 rounded-xl p-4 shadow-xl shadow-zinc-900" hx-get="/api/rabbitmq/overview" hx-target="content" hx-trigger="every 3s">
  <div class="grid grid-cols-[0.99fr_auto]">
    <h2 class="text-2xl"> RabbitMQ Status</h2>
    <div class="grid grid-rows-[1fr] gap-1" x-data="{increment: 5, label: 'Refresh'}">
      <div class="w-full">
        Auto-refresh: <span @tick.window="increment=increment > 1 ? increment-1 : 0;" x-text="increment"></span>
      </div>
      <button x-text="label" @tick.window="label=increment == 0 ? 'In progress...' : 'Refresh'" class="outline bg-zinc-700 p-1 pl-2 pr-2 rounded-xl w-full" hx-get="/api/rabbitmq/overview" hx-target="content"></button>
    </div>
  </div>
  <div class="border-t border-white mt-4 pt-4">
    <div class="rounded-xl p-2 bg-zinc-700 inset-shadow-sm inset-shadow-zinc-600">
      <h3 class="text-xl">Message Stats</h3>
      <table>
        <thead>
          <tr>
            <th scope="column" class="bg-zinc-700 p-1">Type</th>
            <th scope="column" class="bg-zinc-700 p-1">Total</th>
            <th scope="column" class="bg-zinc-700 p-1">Rate</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <th scope="row" class="bg-zinc-700 p-1">Publish</th>
            <td class="p-1">{{.overview.message_stats.publish}}</td>
            <td class="p-1">{{.overview.message_stats.publish_details.rate}}</td>
          </tr>
          <tr>
            <th scope="row" class="bg-zinc-700 p-1">Ack</th>
            <td class="p-1">{{.overview.message_stats.ack}}</td>
            <td class="p-1">{{.overview.message_stats.ack_details.rate}}</td>
          </tr>
          <tr>
            <th scope="row" class="bg-zinc-700 p-1">Deliver</th>
            <td class="p-1">{{.overview.message_stats.deliver}} ({{.overview.message_stats.deliver_no_ack}} not ack-ed)</td>
            <td class="p-1">{{.overview.message_stats.deliver_details.rate}} ({{.overview.message_stats.deliver_no_ack_details.rate}} not ack-ed)</td>
          </tr>
        </tbody>
      </table>
    <div>
  <div>
</article>
