<form>
  <div hx-target="this" hx-swap="outerHTML">
    <div><label>Version</label>: {{.version}}</div>
    <button hx-get="/api/system/info/edit" class="btn primary">
      Click To Edit
    </button>
  </div>
</form>

