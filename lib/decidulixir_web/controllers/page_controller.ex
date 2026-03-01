defmodule DecidulixirWeb.PageController do
  use DecidulixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
