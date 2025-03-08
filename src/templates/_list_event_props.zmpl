@args props: []const u8
@html INNER
<td scope="row"
    class="flex gap-4 align-center justify-end bg-zinc-700 text-lg p-1"
    x-data="{
              props: JSON.parse('{{props}}'),
            }">
  <template x-for="(value, index) in props">
    <div class="bg-amber-300 text-black w-fit px-4 py-2 rounded-full">
      <span x-text="index"></span> | <span class="font-bold" x-text="value"></span>
    </div>
  </template>
</td>
INNER
