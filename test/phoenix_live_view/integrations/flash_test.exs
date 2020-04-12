defmodule Phoenix.LiveView.FlashIntegrationTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.{Endpoint, Router}

  @endpoint Endpoint

  setup do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.bypass_through(Router, [:browser])
      |> get("/")

    {:ok, conn: conn}
  end

  describe "LiveView <=> LiveView" do
    test "redirect with flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      {:ok, conn} =
        flash_child
        |> render_click("redirect", %{"to" => "/flash-root", "info" => "ok!"})
        |> follow_redirect(conn)

      assert conn.resp_body =~ "root[ok!]:info"

      flash = assert_redirected(flash_child, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "redirect with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")
      render_click(flash_child, "set_error", %{"error" => "ok!"})

      {:ok, conn} =
        flash_child
        |> render_click("redirect", %{"to" => "/flash-root", "info" => "ok!"})
        |> follow_redirect(conn, "/flash-root")

      assert conn.resp_body =~ "root[ok!]:info"

      flash = assert_redirected(flash_child, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "push_redirect with flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      {:ok, root_child, disconnected_html} =
        flash_child
        |> render_click("push_redirect", %{"to" => "/flash-root", "info" => "ok!"})
        |> follow_redirect(conn, "/flash-root")

      assert disconnected_html =~ "root[ok!]:info"
      assert render(root_child) =~ "root[ok!]:info"

      flash = assert_redirected(flash_child, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "push_redirect with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      render_click(flash_child, "set_error", %{"error" => "ok!"})

      {:ok, root_child, disconnected_html} =
        flash_child
        |> render_click("push_redirect", %{"to" => "/flash-root", "info" => "ok!"})
        |> follow_redirect(conn, "/flash-root")

      assert disconnected_html =~ "root[ok!]:info"
      assert render(root_child) =~ "root[ok!]:info"

      flash = assert_redirected(flash_child, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "push_patch with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      result =
        render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert result =~ "uri[http://localhost:4000/flash-root?foo]"
      assert result =~ "root[ok!]:info"

      assert assert_patch(flash_live, "/flash-root?foo") == :ok
    end

    test "push_patch with flash does not include previous event flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")
      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "root[oops!]:error"

      result =
        render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert result =~ "uri[http://localhost:4000/flash-root?foo]"
      assert result =~ "root[ok!]:info"
      assert result =~ "root[]:error"

      assert assert_patch(flash_live, "/flash-root?foo") == :ok
    end

    test "clears flash on client-side patches", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")
      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "root[oops!]:error"

      result = render_patch(flash_live, "/flash-root?foo=bar")
      assert result =~ "root[]:error"
      assert_patched(flash_live, "/flash-root?foo=bar")
    end

    test "clears flash when passed down to component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      result = render_click(flash_live, "set_error", %{"error" => "oops!"})
      assert result =~ "stateless_component[oops!]:error"

      result = render_click(flash_live, "clear_flash", %{"kind" => "error"})
      assert result =~ "stateless_component[]:error"
    end

    test "nested redirect with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_live_child(flash_live, "flash-child")
      render_click(flash_child, "redirect", %{"to" => "/flash-root?redirect", "info" => "ok!"})
      flash = assert_redirect(flash_child, "/flash-root?redirect")
      assert flash == %{"info" => "ok!"}
    end

    test "nested push_redirect with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_live_child(flash_live, "flash-child")
      render_click(flash_child, "push_redirect", %{"to" => "/flash-root?push", "info" => "ok!"})
      flash = assert_redirect(flash_child, "/flash-root?push")
      assert flash == %{"info" => "ok!"}
    end

    test "nested push_patch with flash", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      flash_child = find_live_child(flash_live, "flash-child")
      render_click(flash_child, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

      result = render(flash_live)
      assert result =~ "uri[http://localhost:4000/flash-root?patch]"
      assert result =~ "root[ok!]"
    end

    test "raises on invalid follow redirect", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")

      assert_raise ArgumentError,
                   "expected LiveView to redirect to \"/wrong\", but got \"/flash-root\"",
                   fn ->
                     flash_child
                     |> render_click("redirect", %{"to" => "/flash-root", "info" => "ok!"})
                     |> follow_redirect(conn, "/wrong")
                   end
    end

    test "raises on invalid assert redirect", %{conn: conn} do
      {:ok, flash_child, _} = live(conn, "/flash-child")
      render_click(flash_child, "redirect", %{"to" => "/flash-root", "info" => "ok!"})

      assert_raise ArgumentError,
                   "expected Phoenix.LiveViewTest.FlashChildLive to redirect to \"/wrong\", but got a redirect to \"/flash-root\"",
                   fn -> assert_redirect(flash_child, "/wrong") end

      {:ok, flash_live, _} = live(conn, "/flash-root")
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert_raise ArgumentError,
                   "expected Phoenix.LiveViewTest.FlashLive to redirect to \"/wrong\", but got a patch to \"/flash-root?foo\"",
                   fn -> assert_redirect(flash_live, "/wrong") end
    end

    test "raises on invalid assert patch", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?foo", "info" => "ok!"})

      assert_raise ArgumentError,
                   "expected Phoenix.LiveViewTest.FlashLive to patch to \"/wrong\", but got a patch to \"/flash-root?foo\"",
                   fn -> assert_patch(flash_live, "/wrong") end

      {:ok, flash_child, _} = live(conn, "/flash-child")
      render_click(flash_child, "redirect", %{"to" => "/flash-root", "info" => "ok!"})

      assert_raise ArgumentError,
                   "expected Phoenix.LiveViewTest.FlashChildLive to patch to \"/wrong\", but got a redirect to \"/flash-root\"",
                   fn -> assert_patch(flash_child, "/wrong") end
    end
  end

  describe "LiveComponent => LiveView" do
    test "redirect with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      {:error, {:redirect, %{flash: _}}} =
        render_click([flash_live, "#flash-component"], "redirect", %{
          "to" => "/flash-root",
          "info" => "ok!"
        })

      flash = assert_redirect(flash_live, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "push_redirect with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      {:error, {:live_redirect, %{flash: _}}} =
        render_click([flash_live, "#flash-component"], "push_redirect", %{
          "to" => "/flash-root",
          "info" => "ok!"
        })

      flash = assert_redirect(flash_live, "/flash-root")
      assert flash == %{"info" => "ok!"}
    end

    test "push_patch with flash from component", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      render_click([flash_live, "#flash-component"], "push_patch", %{
        "to" => "/flash-root?patch",
        "info" => "ok!"
      })

      result = render(flash_live)
      assert result =~ "uri[http://localhost:4000/flash-root?patch]"
      assert result =~ "root[ok!]"
    end
  end

  describe "LiveView <=> DeadView" do
    test "redirect with flash from LiveView to DeadView", %{conn: conn} do
      {:ok, flash_live, _} = live(conn, "/flash-root")

      {:error, {:redirect, %{flash: _}}} =
        render_click(flash_live, "redirect", %{"to" => "/", "info" => "ok!"})

      flash = assert_redirect(flash_live, "/")
      assert flash == %{"info" => "ok!"}
    end

    test "redirect with flash from DeadView to LiveView", %{conn: conn} do
      conn =
        conn
        |> LiveView.Router.fetch_live_flash([])
        |> Phoenix.Controller.put_flash(:info, "flash from the dead")
        |> Phoenix.Controller.redirect(to: "/flash-root")
        |> get("/flash-root")

      assert html_response(conn, 200) =~ "flash from the dead"
      {:ok, _flash_live, html} = live(conn)
      assert html =~ "flash from the dead"
    end
  end

  test "lv:clear-flash", %{conn: conn} do
    {:ok, flash_live, _} = live(conn, "/flash-root")

    result =
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

    assert result =~ "uri[http://localhost:4000/flash-root?patch]"
    assert result =~ "root[ok!]:info"

    result = render_click(flash_live, "lv:clear-flash", %{key: "info"})
    assert result =~ "root[]:info"

    result =
      render_click(flash_live, "push_patch", %{"to" => "/flash-root?patch", "info" => "ok!"})

    assert result =~ "uri[http://localhost:4000/flash-root?patch]"
    assert result =~ "root[ok!]:info"

    result = render_click(flash_live, "lv:clear-flash")
    assert result =~ "root[]:info"
  end

  test "lv:clear-flash component", %{conn: conn} do
    {:ok, flash_live, _} = live(conn, "/flash-root")

    result = render_click([flash_live, "#flash-component"], "put_flash", %{"info" => "ok!"})
    assert result =~ "component[ok!]:info"

    result = render_click([flash_live, "#flash-component"], "lv:clear-flash")
    assert result =~ "component[]:info"

    result = render_click([flash_live, "#flash-component"], "put_flash", %{"error" => "oops!"})
    assert result =~ "component[oops!]:error"

    result = render_click([flash_live, "#flash-component"], "lv:clear-flash", %{key: "error"})
    assert result =~ "component[]:error"
  end

  test "works without flash", %{conn: conn} do
    {:ok, live, html} = live(conn, "/thermo-with-metadata")
    assert html =~ "The temp is: 1"
    assert render(live) =~ "The temp is: 1"
  end
end
