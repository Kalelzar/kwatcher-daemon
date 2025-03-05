@args timestamp: i64
@html INNER
<td scope="row"
    class="bg-zinc-700 text-lg p-1"
    x-data="{
               get timestamp() { return duration({{timestamp}}); },
            }"
    x-text="timestamp">
</td>
INNER