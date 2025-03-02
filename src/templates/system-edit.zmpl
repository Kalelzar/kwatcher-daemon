<form>
  <form hx-ext="form-json"  hx-put="/api/system/info" hx-target="this" hx-swap="outerHTML">
    <div>
      <label>Version</label>
      <input type="text" name="version" value="{{.version}}">
    </div>
    <button class="btn">Submit</button>
    <button class="btn" hx-get="/api/system/info">Cancel</button>
  </form>
</form>

