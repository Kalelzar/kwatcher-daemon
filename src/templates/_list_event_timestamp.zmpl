@args timestamp: i64
@html INNER
<td scope="row"
    class="text-lg p-1"
    x-data="{
              timestamp: '{{timestamp}}',
              get date() { return new Date(+(this.timestamp.substring(0, 13))).toLocaleString(); }
            }"
    x-text="date">
</td>
INNER