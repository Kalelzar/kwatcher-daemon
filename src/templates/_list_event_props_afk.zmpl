@args props: []const u8
@html INNER
<td scope="row"
    class="flex gap-4 align-center justify-end bg-zinc-700 text-lg p-1"
    x-data="{
              props: JSON.parse('{{props}}'),
              get isAfk() { return this.props.status !== 'Active'; },
            }">
    <div class="bg-red-300 text-black w-full px-4 py-2 rounded-se-4xl rounded-ee-4xl rounded-ss-md rounded-es-md" x-show="isAfk">
      <span class="font-bold">Inactive</span>
    </div>
    <div class="bg-green-300 text-black w-full px-4 py-2 rounded-se-4xl rounded-ee-4xl rounded-ss-md rounded-es-md" x-show="!isAfk">
      <span class="font-bold">Active</span>
    </div> 
</td>
INNER
