# Installation

**Note:** Phoenix v1.5 comes with built-in support for LiveView apps. Just create
your application with `mix phx.new my_app --live`. If you are using earlier Phoenix
versions or your app already exists, keep on reading.

The instructions below will serve if you are installing the latest stable version
from Hex. To start using LiveView, add to your `mix.exs` and run `mix deps.get`.

If installing from Hex, use the latest version from there:

```elixir
def deps do
  [
    {:phoenix_live_view, "~> 0.12.1"},
    {:floki, ">= 0.0.0", only: :test}
  ]
end
```

If you want the latest features, install from GitHub:

```elixir
def deps do
  [
    {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"},
    {:floki, ">= 0.0.0", only: :test}
  ]
```

Once installed, update your endpoint's configuration to include a signing salt.
You can generate a signing salt by running `mix phx.gen.secret 32`:

```elixir
# config/config.exs

config :my_app, MyAppWeb.Endpoint,
   live_view: [
     signing_salt: "SECRET_SALT"
   ]
```

Next, add the following imports to your web file in `lib/my_app_web.ex`:

```elixir
# lib/my_app_web.ex

def controller do
  quote do
    ...
    import Phoenix.LiveView.Controller
  end
end

def view do
  quote do
    ...
    import Phoenix.LiveView.Helpers
  end
end

def router do
  quote do
    ...
    import Phoenix.LiveView.Router
  end
end
```

Then add the `Phoenix.LiveView.Router.fetch_live_flash/2` plug to your browser pipeline, in place of `:fetch_flash`:

```diff
# lib/my_app_web/router.ex

pipeline :browser do
  ...
  plug :fetch_session
- plug :fetch_flash
+ plug :fetch_live_flash
end
```

Next, expose a new socket for LiveView updates in your app's endpoint module.

```elixir
# lib/my_app_web/endpoint.ex

defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint

  # ...

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # ...
end
```

Where `@session_options` are the options given to `plug Plug.Session` extracted to a module attribute. If you don't have a `@session_options` in your endpoint yet, here is how to extract it out:

1. Find plug Plug.Session in your endpoint.ex

```elixir
  plug Plug.Session
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "somesigningsalt"
```

2. Move the options to a module attribute at the top of your file:

```elixir
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "somesigningsalt"
  ]
```

3. Change the plug Plug.Session to use the attribute:

```elixir
  plug Plug.Session, @session_options
```

Add LiveView NPM dependencies in your `assets/package.json`. For a regular project, do:

```json
{
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  }
}
```

However, if you're adding `phoenix_live_view` to an umbrella project, the dependency paths should be modified appropriately:

```json
{
  "dependencies": {
    "phoenix": "file:../../../deps/phoenix",
    "phoenix_html": "file:../../../deps/phoenix_html",
    "phoenix_live_view": "file:../../../deps/phoenix_live_view"
  }
}
```

Then install the new npm dependency.

```bash
npm install --prefix assets
```

If you had previously installed `phoenix_live_view` and want to get the
latest javascript, then force an install.

```bash
npm install --force phoenix_live_view --prefix assets
```

Finally ensure you have placed a CSRF meta tag inside the `<head>` tag in your layout (`lib/my_app_web/templates/layout/app.html.eex`), before `app.js` is included like so:

```html
<%= csrf_meta_tag() %>
<script type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
```

and enable connecting to a LiveView socket in your `app.js` file.

```javascript
// assets/js/app.js
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
```

## Layouts

LiveView does not use the default app layout. Instead, you typically call `put_root_layout` in your router to specify a layout that is used by both "regular" views and live views. In your router, do:

```elixir
pipeline :browser do
  ...
  plug :put_root_layout, {MyAppWeb.LayoutView, "root.html"}
  ...
end
```

The layout given to `put_root_layout` must use `@inner_content` instead of `<%= render(@view_module, @view_template, assigns) %>`. Then you can use "app.html.eex" for a layout specific to "regular" views and a "live.html.eex" that is specific to live views. Check the [Live Layouts](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-live-layouts) section of the docs for more information.

## phx.gen.live support

While the instructions above are enough to install LiveView in a Phoenix app, if you want to use the `phx.gen.live` generators that come as part of Phoenix v1.5, you need to do one more change, as those generators assume your application was created with `mix phx.new --live`.

The change is to define the `live_view` and `live_component` functions in your `web.ex` file, while refactoring the `view` function. At the end, they will look like this:

```elixir
  def view do
    quote do
      use Phoenix.View,
        root: "lib/<%= lib_web_name %>/templates",
        namespace: <%= web_namespace %>

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {<%= web_namespace %>.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import MyAppWeb.ErrorHelpers
      import MyAppWeb.Gettext
      alias MyAppWeb.Router.Helpers, as: Routes
    end
  end
```

Note that LiveViews are automatically configured to add use a "live.html.eex" layout in this line:

```elixir
use Phoenix.LiveView,
  layout: {<%= web_namespace %>.LayoutView, "live.html"}
```

This means "root.html.eex" is shared by regular and live views, "app.html.eex" is
rendered inside the root layout for regular views, and "live.html.leex" is rendered
inside the root layout for LiveViews. So make sure that you follow the steps outlined
in the previous "Layouts" section.

## Progress animation

If you want to show a progress bar as users perform live actions, we recommend using [`nprogress`](https://github.com/rstacruz/nprogress).

First add `nprogress` as a dependency in your `assets/package.json`:

```json
"nprogress": "^0.2.0"
```

Then in your `assets/css/app.css` file, import its style:

```css
@import "../node_modules/nprogress/nprogress.css";
```

Finally customize LiveView to use it in your `assets/js/app.js`, right before the `liveSocket.connect()` call:

```js
import NProgress from "nprogress"

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())
```
