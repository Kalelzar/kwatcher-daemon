@args props: []const u8
@html INNER
<td scope="row"
    class="flex gap-4 align-center justify-end bg-zinc-700 text-lg p-1"
    x-data="{
              props: JSON.parse(`{{props}}`),
              get isPlaying() { return this.props.playing; },
              get title() { return this.props.title; },
              get artist() { return this.props.artist; },
              get album() { return this.props.album; },
              get cover() { return this.props.cover_uri; },
            }">
    <div class="grid outline-yellow-100 outline-solid outline-1 drop-shadow-xl w-full text-center px-4 py-2 grid-cols-[auto_0.5fr_auto_0.5fr] bg-zinc-500 rounded-se-4xl rounded-ee-4xl rounded-ss-md rounded-es-md" x-show="isPlaying">
         <img class="max-w-24 row-start-1 row-end-3 outline-zinc-300 outline-solid rounded-md" x-bind:src="cover">
         <p class="text-yellow-100 text-2xl w-full col-start-2 col-end-5" x-text="title"></p>
         <p x-text="album" class="text-yellow-100"></p>
         <p> </p>
         <p x-text="artist" class="text-yellow-100"></p>
    </div>
    <div x-show="!isPlaying" class="outline-yellow-100 outline-solid outline-1 drop-shadow-xl w-full px-4 py-2 bg-zinc-500 rounded-se-4xl rounded-ee-4xl rounded-ss-md rounded-es-md">
         <p class="text-yellow-100 text-xl w-full float-left">Paused</p>
    </div>
</td>
INNER